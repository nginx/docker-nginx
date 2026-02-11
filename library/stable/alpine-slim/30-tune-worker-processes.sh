#!/bin/sh
# vim:sw=2:ts=2:sts=2:et

set -eu

LC_ALL=C
ME=$(basename "$0")
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[ "${NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE:-}" ] || exit 0

touch /etc/nginx/nginx.conf 2>/dev/null || { echo >&2 "$ME: error: can not modify /etc/nginx/nginx.conf (read-only file system?)"; exit 0; }

ceildiv() {
  num=$1
  div=$2
  echo $(( (num + div - 1) / div ))
}

get_cpuset() {
  cpusetroot=$1
  cpusetfile=$2
  ncpu=0
  [ -f "$cpusetroot/$cpusetfile" ] || return 1
  for token in $( tr ',' ' ' < "$cpusetroot/$cpusetfile" ); do
    case "$token" in
      *-*)
        count=$( seq $(echo "$token" | tr '-' ' ') | wc -l )
        ncpu=$(( ncpu+count ))
        ;;
      *)
        ncpu=$(( ncpu+1 ))
        ;;
    esac
  done
  echo "$ncpu"
}

get_quota() {
  cpuroot=$1
  ncpu=0
  [ -f "$cpuroot/cpu.cfs_quota_us" ] || return 1
  [ -f "$cpuroot/cpu.cfs_period_us" ] || return 1
  cfs_quota=$( cat "$cpuroot/cpu.cfs_quota_us" )
  cfs_period=$( cat "$cpuroot/cpu.cfs_period_us" )
  [ "$cfs_quota" = "-1" ] && return 1
  [ "$cfs_period" = "0" ] && return 1
  ncpu=$( ceildiv "$cfs_quota" "$cfs_period" )
  [ "$ncpu" -gt 0 ] || return 1
  echo "$ncpu"
}

get_quota_v2() {
  cpuroot=$1
  ncpu=0
  [ -f "$cpuroot/cpu.max" ] || return 1
  cfs_quota=$( cut -d' ' -f 1 < "$cpuroot/cpu.max" )
  cfs_period=$( cut -d' ' -f 2 < "$cpuroot/cpu.max" )
  [ "$cfs_quota" = "max" ] && return 1
  [ "$cfs_period" = "0" ] && return 1
  ncpu=$( ceildiv "$cfs_quota" "$cfs_period" )
  [ "$ncpu" -gt 0 ] || return 1
  echo "$ncpu"
}

get_cgroup_v1_path() {
  needle=$1
  found=
  foundroot=
  mountpoint=

  [ -r "/proc/self/mountinfo" ] || return 1
  [ -r "/proc/self/cgroup" ] || return 1

  while IFS= read -r line; do
    case "$needle" in
      "cpuset")
        case "$line" in
          *cpuset*)
            found=$( echo "$line" | cut -d ' ' -f 4,5 )
            break
            ;;
        esac
        ;;
      "cpu")
        case "$line" in
          *cpuset*)
            ;;
          *cpu,cpuacct*|*cpuacct,cpu|*cpuacct*|*cpu*)
            found=$( echo "$line" | cut -d ' ' -f 4,5 )
            break
            ;;
        esac
    esac
  done << __EOF__
$( grep -F -- '- cgroup ' /proc/self/mountinfo )
__EOF__

  while IFS= read -r line; do
    controller=$( echo "$line" | cut -d: -f 2 )
    case "$needle" in
      "cpuset")
        case "$controller" in
          cpuset)
            mountpoint=$( echo "$line" | cut -d: -f 3 )
            break
            ;;
        esac
        ;;
      "cpu")
        case "$controller" in
          cpu,cpuacct|cpuacct,cpu|cpuacct|cpu)
            mountpoint=$( echo "$line" | cut -d: -f 3 )
            break
            ;;
        esac
        ;;
    esac
done << __EOF__
$( grep -F -- 'cpu' /proc/self/cgroup )
__EOF__

  case "${found%% *}" in
    "/")
      foundroot="${found##* }$mountpoint"
      ;;
    "$mountpoint")
      foundroot="${found##* }"
      ;;
  esac
  echo "$foundroot"
}

get_cgroup_v2_path() {
  found=
  foundroot=
  mountpoint=

  [ -r "/proc/self/mountinfo" ] || return 1
  [ -r "/proc/self/cgroup" ] || return 1

  while IFS= read -r line; do
    found=$( echo "$line" | cut -d ' ' -f 4,5 )
  done << __EOF__
$( grep -F -- '- cgroup2 ' /proc/self/mountinfo )
__EOF__

  while IFS= read -r line; do
    mountpoint=$( echo "$line" | cut -d: -f 3 )
done << __EOF__
$( grep -F -- '0::' /proc/self/cgroup )
__EOF__

  case "${found%% *}" in
    "")
      return 1
      ;;
    "/")
      foundroot="${found##* }$mountpoint"
      ;;
    "$mountpoint" | /../*)
      foundroot="${found##* }"
      ;;
  esac
  echo "$foundroot"
}

ncpu_online=$( getconf _NPROCESSORS_ONLN )
ncpu_cpuset=
ncpu_quota=
ncpu_cpuset_v2=
ncpu_quota_v2=

cpuset=$( get_cgroup_v1_path "cpuset" ) && ncpu_cpuset=$( get_cpuset "$cpuset" "cpuset.effective_cpus" ) || ncpu_cpuset=$ncpu_online
cpu=$( get_cgroup_v1_path "cpu" ) && ncpu_quota=$( get_quota "$cpu" ) || ncpu_quota=$ncpu_online
cgroup_v2=$( get_cgroup_v2_path ) && ncpu_cpuset_v2=$( get_cpuset "$cgroup_v2" "cpuset.cpus.effective" ) || ncpu_cpuset_v2=$ncpu_online
cgroup_v2=$( get_cgroup_v2_path ) && ncpu_quota_v2=$( get_quota_v2 "$cgroup_v2" ) || ncpu_quota_v2=$ncpu_online

ncpu=$( printf "%s\n%s\n%s\n%s\n%s\n" \
               "$ncpu_online" \
               "$ncpu_cpuset" \
               "$ncpu_quota" \
               "$ncpu_cpuset_v2" \
               "$ncpu_quota_v2" \
               | sort -n \
               | head -n 1 )

sed -i.bak -r 's/^(worker_processes)(.*)$/# Commented out by '"$ME"' on '"$(date)"'\n#\1\2\n\1 '"$ncpu"';/' /etc/nginx/nginx.conf
