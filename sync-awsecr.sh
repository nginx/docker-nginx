#!/bin/bash
set -eu

image="nginx"
registry="public.ecr.aws/z9d2n7e1"

declare -A aliases
aliases=(
    [mainline]='1 1.29 latest'
    [stable]='1.28'
)

architectures=( amd64 arm64v8 )

self="$(basename "$BASH_SOURCE")"
cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"
base=debian

versions=( mainline stable )

pulllist=()
declare -A taglist
taglist=()

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

# prints "$2$1$3$1...$N"
join() {
    local sep="$1"; shift
    local out; printf -v out "${sep//%/%%}%s" "$@"
    echo "${out#$sep}"
}

for version in "${versions[@]}"; do
    commit="$(dirCommit "$version/$base")"
    fullVersion="$(git show "$commit":"$version/$base/Dockerfile" | awk '$1 == "ENV" && $2 == "NGINX_VERSION" { print $3; exit }')"
    pulllist+=( "$image:$fullVersion" )
    for variant in otel perl alpine alpine-otel alpine-perl alpine-slim; do
        pulllist+=( "$image:$fullVersion-$variant" )
    done
done

for version in "${versions[@]}"; do
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

    for tag in ${versionAliases[@]:1} ${debianAliases[@]:1}; do
        taglist["$image:$tag"]="$image:$fullVersion"
    done

    for variant in debian-perl; do
        variantAliases=( "${versionAliases[@]/%/-perl}" )
        variantAliases+=( "${versionAliases[@]/%/-${variant/debian/$debianVersion}}" )
        variantAliases=( "${variantAliases[@]//latest-/}" )

        for tag in ${variantAliases[@]}; do
        if [ "$tag" != "${fullVersion}-perl" ]; then
            taglist["$image:$tag"]="$image:$fullVersion-perl"
        fi
        done
    done

    for variant in debian-otel; do
        variantAliases=( "${versionAliases[@]/%/-otel}" )
        variantAliases+=( "${versionAliases[@]/%/-${variant/debian/$debianVersion}}" )
        variantAliases=( "${variantAliases[@]//latest-/}" )

        for tag in ${variantAliases[@]}; do
        if [ "$tag" != "${fullVersion}-otel" ]; then
            taglist["$image:$tag"]="$image:$fullVersion-otel"
        fi
        done
    done

    commit="$(dirCommit "$version/alpine-slim")"
    alpineVersion="$(git show "$commit":"$version/alpine-slim/Dockerfile" | awk -F: '$1 == "FROM alpine" { print $2; exit }')"

    for variant in alpine alpine-otel alpine-perl alpine-slim; do
        commit="$(dirCommit "$version/$variant")"

        variantAliases=( "${versionAliases[@]/%/-$variant}" )
        variantAliases+=( "${versionAliases[@]/%/-${variant/alpine/alpine$alpineVersion}}" )
        variantAliases=( "${variantAliases[@]//latest-/}" )

        for tag in ${variantAliases[@]}; do
            if [ "$tag" != "${fullVersion}-$variant" ]; then
                taglist["$image:$tag"]="$image:${fullVersion}-$variant"
            fi
        done
    done

done

echo "#!/bin/sh"
echo "set -ex"
echo
echo "export DOCKER_CLI_EXPERIMENTAL=enabled"
echo
echo "# pulling stuff"
for arch in ${architectures[@]}; do
    case $arch in
        arm64v8)
            parch="aarch64"
            ;;
        *)
            parch=$arch
            ;;
    esac
for tag in ${pulllist[@]}; do
    echo "docker pull --platform linux/$parch $arch/$tag";
done
done

echo

echo "# tagging stuff"

for arch in ${architectures[@]}; do
for tag in ${pulllist[@]}; do
    echo "docker tag $arch/$tag $registry/$tag-$arch"
done
for tag in ${!taglist[@]}; do
    echo "docker tag $arch/${taglist[$tag]} $registry/$tag-$arch"
done
done

echo "# pushing stuff"

for arch in ${architectures[@]}; do
for tag in ${pulllist[@]}; do
    echo "docker push $registry/$tag-$arch"
done
for tag in ${!taglist[@]}; do
    echo "docker push $registry/$tag-$arch"
done
done

echo
echo "# manifesting and pushing stuff"
for tag in ${pulllist[@]} ${!taglist[@]}; do
    string="docker buildx imagetools create --progress=plain -t $registry/$tag"
    for arch in ${architectures[@]}; do
        string+=" $registry/$tag-$arch"
    done
    echo $string
done
