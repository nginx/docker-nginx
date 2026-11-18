#!/bin/bash

[ "$DEBUG" ] && set -x

set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

clientImage='buildpack-deps:buster-curl'
# ensure the clientImage is ready and available
if ! docker image inspect "$clientImage" &> /dev/null; then
	docker pull "$clientImage" > /dev/null
fi

# Create an instance of the container-under-test
serverImage="$("$HOME/oi/test/tests/image-name.sh" librarytest/nginx-template "$image")"
"$HOME/oi/test/tests/docker-build.sh" "$dir" "$serverImage" <<EOD
FROM $image
COPY dir/server.conf.template /etc/nginx/templates/server.conf.template
EOD
cid="$(docker run -d -e NGINX_MY_SERVER_NAME=example.com "$serverImage")"
trap "docker rm -vf $cid > /dev/null" EXIT

_request() {
	local method="$1"
	shift

	local proto="$1"
	shift

	local url="${1#/}"
	shift

	if [ "$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null)" != 'true' ]; then
		echo >&2 "$image stopped unexpectedly!"
		( set -x && docker logs "$cid" ) >&2 || true
		false
	fi

	docker run --rm \
		--link "$cid":nginx \
		"$clientImage" \
		curl -fsSL -X"$method" --connect-to '::nginx:' "$@" "$proto://example.com/$url"
}

. "$HOME/oi/test/retry.sh" '[ "$(_request GET / --output /dev/null || echo $?)" != 7 ]'

# Check that we can request /
_request GET http '/templates' | grep 'example.com - OK'
