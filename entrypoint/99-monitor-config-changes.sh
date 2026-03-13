#!/bin/sh
# vim:sw=2:ts=2:sts=2:et

set -eu
if [ -n "${DEBUG_TRACE_SH:-}" ] && \
   [ "${DEBUG_TRACE_SH:-}" != "${DEBUG_TRACE_SH#*"$(basename "${0}")"*}" ] || \
   [ "${DEBUG_TRACE_SH:-}" = 'all' ]; then
  set -x
fi

LC_ALL=C

if [ -e "${NGINX_ENTRYPOINT_MONITOR_PID:=/run/nginx_monitor.pid}" ] ||
   [ -z "${NGINX_ENTRYPOINT_MONITOR_CONFIG+monitor}" ] || \
   ! command -v inotifywait; then
  exit 0
fi

echo "Monitoring for changes in '${NGINX_ENTRYPOINT_MONITOR_CONFIG:=/etc/nginx}'"
while true; do
  inotifywait \
    --recursive \
    --event 'create' \
    --event 'delete' \
    --event 'modify' \
    --event 'move' \
    "${NGINX_ENTRYPOINT_MONITOR_CONFIG}"

  sleep "${NGINX_ENTRYPOINT_MONITOR_DELAY:-10s}"

  if [ ! -e "${NGINX_ENTRYPOINT_MONITOR_PID}" ]; then
    logger -s -t 'nginx' -p 'local0.3' 'Monitor failure or exit requested'
    break
  fi

  if nginx -t; then
    nginx -s
  else
    logger -s -t 'nginx' -p 'local0.3' 'Refusing to reload config, config error'
  fi
done &
echo "${!}" > "${NGINX_ENTRYPOINT_MONITOR_PID}"

exit 0
