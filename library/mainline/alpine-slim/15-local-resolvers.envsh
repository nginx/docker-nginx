#!/bin/sh
# vim:sw=2:ts=2:sts=2:et

set -eu

LC_ALL=C
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[ "${NGINX_ENTRYPOINT_LOCAL_RESOLVERS:-}" ] || return 0

NGINX_LOCAL_RESOLVERS=$(awk 'BEGIN{ORS=" "} $1=="nameserver" {if ($2 ~ ":") {print "["$2"]"} else {print $2}}' /etc/resolv.conf)

NGINX_LOCAL_RESOLVERS="${NGINX_LOCAL_RESOLVERS% }"

export NGINX_LOCAL_RESOLVERS
