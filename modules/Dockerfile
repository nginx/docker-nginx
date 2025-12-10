ARG NGINX_FROM_IMAGE=nginx:mainline
FROM ${NGINX_FROM_IMAGE} AS builder

ARG ENABLED_MODULES

SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

RUN if [ "$ENABLED_MODULES" = "" ]; then \
        echo "No additional modules enabled, exiting"; \
        exit 1; \
    fi

COPY ./ /modules/

RUN apt-get update \
    && apt-get install -y --no-install-suggests --no-install-recommends \
                patch make wget git devscripts debhelper dpkg-dev \
                quilt lsb-release build-essential libxml2-utils xsltproc \
                equivs git g++ libparse-recdescent-perl \
    && XSLSCRIPT_SHA512="f7194c5198daeab9b3b0c3aebf006922c7df1d345d454bd8474489ff2eb6b4bf8e2ffe442489a45d1aab80da6ecebe0097759a1e12cc26b5f0613d05b7c09ffa *stdin" \
    && wget -O /tmp/xslscript.pl https://raw.githubusercontent.com/nginx/xslscript/9204424259c343ca08a18a78915f40f28025e093/xslscript.pl \
    && if [ "$(cat /tmp/xslscript.pl | openssl sha512 -r)" = "$XSLSCRIPT_SHA512" ]; then \
        echo "XSLScript checksum verification succeeded!"; \
        chmod +x /tmp/xslscript.pl; \
        mv /tmp/xslscript.pl /usr/local/bin/; \
    else \
        echo "XSLScript checksum verification failed!"; \
        exit 1; \
    fi \
    && git clone -b ${NGINX_VERSION}-${PKG_RELEASE%%~*} https://github.com/nginx/pkg-oss/ \
    && cd pkg-oss \
    && mkdir /tmp/packages \
    && for module in $ENABLED_MODULES; do \
        echo "Building $module for nginx-$NGINX_VERSION"; \
        if [ -d /modules/$module ]; then \
            echo "Building $module from user-supplied sources"; \
            # check if module sources file is there and not empty
            if [ ! -s /modules/$module/source ]; then \
                echo "No source file for $module in modules/$module/source, exiting"; \
                exit 1; \
            fi; \
            # some modules require build dependencies
            if [ -f /modules/$module/build-deps ]; then \
                echo "Installing $module build dependencies"; \
                apt-get update && apt-get install -y --no-install-suggests --no-install-recommends $(cat /modules/$module/build-deps | xargs); \
            fi; \
            # if a module has a build dependency that is not in a distro, provide a
            # shell script to fetch/build/install those
            # note that shared libraries produced as a result of this script will
            # not be copied from the builder image to the main one so build static
            if [ -x /modules/$module/prebuild ]; then \
                echo "Running prebuild script for $module"; \
                /modules/$module/prebuild; \
            fi; \
            /pkg-oss/build_module.sh -v $NGINX_VERSION -f -y -o /tmp/packages -n $module $(cat /modules/$module/source); \
            BUILT_MODULES="$BUILT_MODULES $(echo $module | tr '[A-Z]' '[a-z]' | tr -d '[/_\-\.\t ]')"; \
        elif make -C /pkg-oss/debian list | grep -P "^$module\s+\d" > /dev/null; then \
            echo "Building $module from pkg-oss sources"; \
            cd /pkg-oss/debian; \
            make rules-module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
            mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends --yes" debuild-module-$module/nginx-$NGINX_VERSION/debian/control; \
            make module-$module BASE_VERSION=$NGINX_VERSION NGINX_VERSION=$NGINX_VERSION; \
            find ../../ -maxdepth 1 -mindepth 1 -type f -name "*.deb" -exec mv -v {} /tmp/packages/ \;; \
            BUILT_MODULES="$BUILT_MODULES $module"; \
        else \
            echo "Don't know how to build $module module, exiting"; \
            exit 1; \
        fi; \
    done \
    && echo "BUILT_MODULES=\"$BUILT_MODULES\"" > /tmp/packages/modules.env

FROM ${NGINX_FROM_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/nginx/nginx"
RUN --mount=type=bind,target=/tmp/packages/,source=/tmp/packages/,from=builder \
    apt-get update \
    && . /tmp/packages/modules.env \
    && for module in $BUILT_MODULES; do \
           apt-get install --no-install-suggests --no-install-recommends -y /tmp/packages/nginx-module-${module}_${NGINX_VERSION}*.deb; \
       done \
    && rm -rf /var/lib/apt/lists/
