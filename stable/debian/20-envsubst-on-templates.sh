#!/bin/sh

set -e

ME=$(basename "$0")

entrypoint_log() {
    if [ -z "${NGINX_ENTRYPOINT_QUIET_LOGS:-}" ]; then
        echo "$@"
    fi
}

ensure_output_writable() {
  local test_dir=$1
  if [ ! -w "$test_dir" ]; then
    entrypoint_log "$ME: ERROR: $template_dir exists, but $test_dir is not writable"
    exit 0
  fi
}

add_extra_block() {
  local extra=$1
  local extra_output_dir=$2
  local conffile="/etc/nginx/nginx.conf"

  if grep -q -E "\s*$extra\s*\{" "$conffile"; then
    entrypoint_log "$ME: $conffile contains a $extra block; include $extra_output_dir/*.conf to enable $extra templates"
  else
    # check if the file can be modified, e.g. not on a r/o filesystem
    touch "$conffile" 2>/dev/null || { entrypoint_log "$ME: info: can not modify $conffile (read-only file system?)"; exit 0; }
    entrypoint_log "$ME: Appending $extra block to $conffile to include $extra_output_dir/*.conf"
    cat << END >> "$conffile"
# added by "$ME" on "$(date)"
$extra {
  include $extra_output_dir/*.conf;
}
END
  fi
}

write_template_conf() {
  local select_suffix=$1
  local conf_output_dir=$2
  local template relative_path output_path subdir
  find "$template_dir" -follow -type f -name "*$select_suffix" -print | while read -r template; do
    relative_path="${template#"$template_dir/"}"
    output_path="$conf_output_dir/${relative_path%"$select_suffix"}"
    subdir=$(dirname "$relative_path")
    # create a subdirectory where the template file exists
    mkdir -p "$conf_output_dir/$subdir"
    entrypoint_log "$ME: Running envsubst on $template to $output_path"
    envsubst "$defined_envs" < "$template" > "$output_path"
  done
}

auto_envsubst() {
  local template_dir="${NGINX_ENVSUBST_TEMPLATE_DIR:-/etc/nginx/templates}"
  local suffix="${NGINX_ENVSUBST_TEMPLATE_SUFFIX:-.template}"
  local output_dir="${NGINX_ENVSUBST_OUTPUT_DIR:-/etc/nginx/conf.d}"
  local mail_suffix="${NGINX_ENVSUBST_MAIL_TEMPLATE_SUFFIX:-.mail-template}"
  local mail_output_dir="${NGINX_ENVSUBST_MAIL_OUTPUT_DIR:-/etc/nginx/mail-conf.d}"
  local stream_suffix="${NGINX_ENVSUBST_STREAM_TEMPLATE_SUFFIX:-.stream-template}"
  local stream_output_dir="${NGINX_ENVSUBST_STREAM_OUTPUT_DIR:-/etc/nginx/stream-conf.d}"
  local filter="${NGINX_ENVSUBST_FILTER:-}"

  local defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" < /dev/null ))
  [ -d "$template_dir" ] || return 0
  ensure_output_writable "$output_dir"
  write_template_conf "$suffix" "$output_dir"

  # Print the first file with the stream suffix, this will be false if there are none
  if test -n "$(find "$template_dir" -name "*$stream_suffix" -print -quit)"; then
    mkdir -p "$stream_output_dir"
    ensure_output_writable "$stream_output_dir"
    add_extra_block "stream" "$stream_output_dir"
    write_template_conf "$stream_suffix" "$stream_output_dir"
  fi
  if test -n "$(find "$template_dir" -name "*$mail_suffix" -print -quit)"; then
    mkdir -p "$mail_output_dir"
    ensure_output_writable "$mail_output_dir"
    add_extra_block "mail" "$mail_output_dir"
    write_template_conf "$mail_suffix" "$mail_output_dir"
  fi
}

auto_envsubst

exit 0
