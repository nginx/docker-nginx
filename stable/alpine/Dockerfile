#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
FROM nginx:1.30.2-alpine-slim

ENV NJS_VERSION   0.9.9
ENV NJS_RELEASE   1
ENV ACME_VERSION  0.4.1

RUN set -x \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${DYNPKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${NJS_RELEASE} \
        nginx-module-acme=${NGINX_VERSION}.${ACME_VERSION}-r${PKG_RELEASE} \
    " \
# install prerequisites for public key and pkg-oss checks
    && apk add --no-cache --virtual .checksum-deps \
        openssl \
    && case "$apkArch" in \
        x86_64|aarch64) \
# arches officially built by upstream
            apk add -X "https://nginx.org/packages/alpine/v$(egrep -o '^[0-9]+\.[0-9]+' /etc/alpine-release)/main" --no-cache $nginxPackages \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                gcc \
                libc-dev \
                make \
                openssl-dev \
                pcre2-dev \
                zlib-dev \
                linux-headers \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                libedit-dev \
                bash \
                alpine-sdk \
                findutils \
                curl \
                cargo \
                clang-libclang \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/60789259bfab36b1669a414881a9d002fd246d6b.tar.gz \
                && PKGOSSCHECKSUM=\"9282a0265c921af3e2d5760cbdc06aae65e6efb145ed266fe02102326174a9e9405f6492979372556c14e2f4f8cf66a48c338d054d0ece375a1c41f343f244cc *60789259bfab36b1669a414881a9d002fd246d6b.tar.gz\" \
                && if [ \"\$(openssl sha512 -r 60789259bfab36b1669a414881a9d002fd246d6b.tar.gz)\" = \"\$PKGOSSCHECKSUM\" ]; then \
                    echo \"pkg-oss tarball checksum verification succeeded!\"; \
                else \
                    echo \"pkg-oss tarball checksum verification failed!\"; \
                    exit 1; \
                fi \
                && tar xzvf 60789259bfab36b1669a414881a9d002fd246d6b.tar.gz \
                && cd pkg-oss-60789259bfab36b1669a414881a9d002fd246d6b \
                && cd alpine \
                && export BUILDTARGET=\"module-geoip module-image-filter module-njs module-xslt module-acme\" \
                && if [ \"\$(apk --print-arch)\" = \"armhf\" ]; then BUILDTARGET=\"\$( echo \$BUILDTARGET | sed 's,module-acme,,' )\"; fi \
                && make \$BUILDTARGET \
                && apk index --allow-untrusted -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
                " \
            && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
            && apk del --no-network .build-deps \
            && if [ "$apkArch" = "armhf" ]; then nginxPackages="$( echo $nginxPackages | sed 's,nginx-module-acme=.*,,')"; fi \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
# remove checksum deps
    && apk del --no-network .checksum-deps \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && if [ -f "/etc/apk/keys/abuild-key.rsa.pub" ]; then rm -f /etc/apk/keys/abuild-key.rsa.pub; fi \
# Bring in curl and ca-certificates to make registering on DNS SD easier
    && apk add --no-cache curl ca-certificates
