#!/bin/bash
set -eu

declare -A aliases
aliases=(
	[mainline]='1 1.27 latest'
	[stable]='1.26'
)

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
base=debian

versions=( mainline stable )

# get the most recent commit which modified any of "$@"
fileCommit() {
	git log -1 --format='format:%H' HEAD -- "$@"
}

# get the most recent commit which modified "$1/Dockerfile" or any file COPY'd from "$1/Dockerfile"
dirCommit() {
	local dir="$1"; shift
	(
		cd "$dir"
		fileCommit \
			Dockerfile \
			$(git show HEAD:./Dockerfile | awk '
				toupper($1) == "COPY" {
					for (i = 2; i < NF; i++) {
						print $i
					}
				}
			')
	)
}

cat <<-EOH
# this file is generated via https://github.com/nginx/docker-nginx/blob/$(fileCommit "$self")/$self

Maintainers: NGINX Docker Maintainers <docker-maint@nginx.com> (@nginx)
GitRepo: https://github.com/nginx/docker-nginx.git
EOH

# prints "$2$1$3$1...$N"
join() {
	local sep="$1"; shift
	local out; printf -v out "${sep//%/%%}%s" "$@"
	echo "${out#$sep}"
}

for version in "${versions[@]}"; do
    debian_otel="debian-otel"
    alpine_otel="alpine-otel"
	commit="$(dirCommit "$version/$base")"

	fullVersion="$(git show "$commit":"$version/$base/Dockerfile" | awk '$1 == "ENV" && $2 == "NGINX_VERSION" { print $3; exit }')"

	versionAliases=( $fullVersion )
	if [ "$version" != "$fullVersion" ]; then
		versionAliases+=( $version )
	fi
	versionAliases+=( ${aliases[$version]:-} )

	debianVersion="$(git show "$commit":"$version/$base/Dockerfile" | awk -F"[-:]" '$1 == "FROM debian" { print $2; exit }')"
	debianAliases=( ${versionAliases[@]/%/-$debianVersion} )
	debianAliases=( "${debianAliases[@]//latest-/}" )

	echo
	cat <<-EOE
		Tags: $(join ', ' "${versionAliases[@]}"), $(join ', ' "${debianAliases[@]}")
		Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x
		GitCommit: $commit
		Directory: $version/$base
	EOE

	for variant in debian-perl; do
		commit="$(dirCommit "$version/$variant")"

		variantAliases=( "${versionAliases[@]/%/-perl}" )
		variantAliases+=( "${versionAliases[@]/%/-${variant/debian/$debianVersion}}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: amd64, arm32v5, arm32v7, arm64v8, i386, mips64le, ppc64le, s390x
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done

	for variant in $debian_otel; do
		commit="$(dirCommit "$version/$variant")"

		variantAliases=( "${versionAliases[@]/%/-otel}" )
		variantAliases+=( "${versionAliases[@]/%/-${variant/debian/$debianVersion}}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: amd64, arm64v8
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done


	commit="$(dirCommit "$version/alpine-slim")"
	alpineVersion="$(git show "$commit":"$version/alpine-slim/Dockerfile" | awk -F: '$1 == "FROM alpine" { print $2; exit }')"

	for variant in alpine alpine-perl alpine-slim; do
		commit="$(dirCommit "$version/$variant")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		variantAliases+=( "${versionAliases[@]/%/-${variant/alpine/alpine$alpineVersion}}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: arm64v8, arm32v6, arm32v7, ppc64le, s390x, i386, amd64, riscv64
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done

	for variant in $alpine_otel; do
		commit="$(dirCommit "$version/$variant")"

		variantAliases=( "${versionAliases[@]/%/-$variant}" )
		variantAliases+=( "${versionAliases[@]/%/-${variant/alpine/alpine$alpineVersion}}" )
		variantAliases=( "${variantAliases[@]//latest-/}" )

		echo
		cat <<-EOE
			Tags: $(join ', ' "${variantAliases[@]}")
			Architectures: amd64, arm64v8
			GitCommit: $commit
			Directory: $version/$variant
		EOE
	done

done
