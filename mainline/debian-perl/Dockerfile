#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#
FROM nginx:1.27.5

RUN set -x; \
    NGINX_GPGKEY_PATH=/etc/apt/keyrings/nginx-archive-keyring.gpg; \
    dpkgArch="$(dpkg --print-architecture)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-perl=${NGINX_VERSION}-${DYNPKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${NJS_RELEASE} \
    " \
    && case "$dpkgArch" in \
        amd64|arm64) \
# arches officialy built by upstream
            echo "deb [signed-by=$NGINX_GPGKEY_PATH] https://nginx.org/packages/mainline/debian/ bookworm nginx" >> /etc/apt/sources.list.d/nginx.list \
            && apt-get update \
            ;; \
        *) \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
# new directory for storing sources and .deb files
            tempDir="$(mktemp -d)" \
            && chmod 777 "$tempDir" \
# (777 to ensure APT's "_apt" user can access it too)
            \
# save list of currently-installed packages so build dependencies can be cleanly removed later
            && savedAptMark="$(apt-mark showmanual)" \
            \
# build .deb files from upstream's packaging sources
            && apt-get update \
            && apt-get install --no-install-recommends --no-install-suggests -y \
                curl \
                devscripts \
                equivs \
                git \
                libxml2-utils \
                lsb-release \
                xsltproc \
            && ( \
                cd "$tempDir" \
                && REVISION="${NGINX_VERSION}-${PKG_RELEASE}" \
                && REVISION=${REVISION%~*} \
                && curl -f -L -O https://github.com/nginx/pkg-oss/archive/${REVISION}.tar.gz \
                && PKGOSSCHECKSUM="c773d98b567bd585c17f55702bf3e4c7d82b676bfbde395270e90a704dca3c758dfe0380b3f01770542b4fd9bed1f1149af4ce28bfc54a27a96df6b700ac1745 *${REVISION}.tar.gz" \
                && if [ "$(openssl sha512 -r ${REVISION}.tar.gz)" = "$PKGOSSCHECKSUM" ]; then \
                    echo "pkg-oss tarball checksum verification succeeded!"; \
                else \
                    echo "pkg-oss tarball checksum verification failed!"; \
                    exit 1; \
                fi \
                && tar xzvf ${REVISION}.tar.gz \
                && cd pkg-oss-${REVISION} \
                && cd debian \
                && for target in module-perl; do \
                    make rules-$target; \
                    mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes" \
                        debuild-$target/nginx-$NGINX_VERSION/debian/control; \
                done \
                && make module-perl \
            ) \
# we don't remove APT lists here because they get re-downloaded and removed later
            \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
            && apt-mark showmanual | xargs apt-mark auto > /dev/null \
            && { [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; } \
            \
# create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
            && ls -lAFh "$tempDir" \
            && ( cd "$tempDir" && dpkg-scanpackages . > Packages ) \
            && grep '^Package: ' "$tempDir/Packages" \
            && echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list \
# work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
#   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
#   ...
#   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
            && apt-get -o Acquire::GzipIndexes=false update \
            ;; \
    esac \
    \
    && apt-get install --no-install-recommends --no-install-suggests -y \
                        $nginxPackages \
                        gettext-base \
                        curl \
    && apt-get remove --purge --auto-remove -y && rm -rf /var/lib/apt/lists/* /etc/apt/sources.list.d/nginx.list \
    \
# if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
    && if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove \
        && rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi
