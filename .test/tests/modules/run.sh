#!/bin/bash

set -eo pipefail

dir="$(dirname "$(readlink -f "$BASH_SOURCE")")"

echo $dir

image="$1"

case "$image" in
    *-perl)
        ;;
    *)
        echo >&2 "skipping non-leaf image: $image"
        exit
        ;;
esac

dockerfile="Dockerfile"
case "$image" in
    *alpine*)
        dockerfile="$dockerfile.alpine"
        ;;
esac

clientImage='buildpack-deps:buster-curl'
# ensure the clientImage is ready and available
if ! docker image inspect "$clientImage" &> /dev/null; then
	docker pull "$clientImage" > /dev/null
fi

# Create an instance of the container-under-test
modulesImage="$("$HOME/oi/test/tests/image-name.sh" librarytest/nginx-template "$image")"
docker build --build-arg NGINX_FROM_IMAGE="$image" --build-arg ENABLED_MODULES="ndk echo" -t "$modulesImage" -f "modules/$dockerfile" "$GITHUB_WORKSPACE/modules"

serverImage="${modulesImage}-sme"
"$HOME/oi/test/tests/docker-build.sh" "$dir" "$serverImage" <<EOD
FROM $modulesImage
COPY dir/nginx.conf.sme /etc/nginx/nginx.conf
EOD

cid="$(docker run -d "$serverImage")"
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
_request GET http '/hello' | grep 'hello'
