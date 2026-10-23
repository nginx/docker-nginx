#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${CONTAINER_ENGINE:-docker}"
image="${NGINX_TEST_IMAGE:-alpine:3.24}"
tmpdir="$(mktemp -d "$root/.entrypoint-ipv6-test.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

config="$tmpdir/default.conf"
printf 'server {\n    listen  [::]:80;\n}\n' > "$config"

output="$("$engine" run --rm --network none \
    --volume "$root/entrypoint/10-listen-on-ipv6-by-default.sh:/entrypoint.sh:ro" \
    --volume "$config:/etc/nginx/conf.d/default.conf:ro" \
    "$image" sh /entrypoint.sh)"
printf '%s\n' "$output"

grep -Fq 'IPv6 listen already enabled' <<<"$output"
if grep -Fq 'can not modify /etc/nginx/conf.d/default.conf' <<<"$output"; then
    exit 1
fi
