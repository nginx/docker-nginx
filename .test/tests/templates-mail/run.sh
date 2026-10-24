#!/bin/bash

[ "$DEBUG" ] && set -x

set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

image="$1"

clientImage='alpine:latest'
# ensure the clientImage is ready and available
if ! docker image inspect "$clientImage" &> /dev/null; then
	docker pull "$clientImage" > /dev/null
fi

# Create an instance of the container-under-test
serverImage="$("$HOME/oi/test/tests/image-name.sh" librarytest/nginx-template "$image")"
"$HOME/oi/test/tests/docker-build.sh" "$dir" "$serverImage" <<EOD
FROM $image

RUN rm -f /etc/nginx/conf.d/default.conf

COPY dir/smtp.conf.mail-template /etc/nginx/templates/smtp.conf.mail-template
COPY dir/smtp_auth_http.conf.template /etc/nginx/templates/smtp_auth_http.conf.template
EOD
cid="$(docker run -d -e NGINX_MY_SERVER_NAME=example.com "$serverImage")"
trap "docker rm -vf $cid > /dev/null" EXIT

_request() {
	if [ "$(docker inspect -f '{{.State.Running}}' "$cid" 2>/dev/null)" != 'true' ]; then
		echo >&2 "$image stopped unexpectedly!"
		( set -x && docker logs "$cid" ) >&2 || true
		false
	fi

	docker run --rm \
		--link "$cid":nginx \
		"$clientImage" \
		nc -w 1 nginx 25
}

. "$HOME/oi/test/retry.sh" '[ "$(_request --output /dev/null || echo $?)" != 7 ]'

# Check that we can open an SMTP connection
_request | grep 'ESMTP ready'
