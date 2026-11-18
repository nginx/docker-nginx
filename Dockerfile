ARG AZLINUX_BASE_VERSION=master

# For local development
FROM quay.io/cdis/amazonlinux-base:${AZLINUX_BASE_VERSION}

LABEL name="revproxy-nginx-modsec"


# https://nginx.org/en/linux_packages.html#Amazon-Linux
COPY nginx.repo /etc/yum.repos.d/nginx.repo
RUN yum install yum-utils -y && yum-config-manager --enable nginx-stable


# Install all necessary packages in one layer
RUN dnf update -y && \
    dnf install -y \
    nginx-1.30.7-1.amzn2023.ngx  \
    nginx-module-njs-1.30.7+1.0.2-1.amzn2023.ngx \
    nginx-module-perl-1.30.7-1.amzn2023.ngx \
    gcc \
    gcc-c++ \
    git \
    make \
    automake \
    autoconf \
    libtool \
    libxml2-devel \
    pcre-devel \
    curl-devel \
    yajl-devel \
    doxygen \
    zlib-devel \
    lmdb-devel \
    flex \
    bison \
    yum-utils \
    wget \
    tar \
    --setopt=install_weak_deps=False \
    --setopt=tsflags=nodocs && \
    dnf clean all && \
    rm -rf /var/cache/yum

# Set working directory
WORKDIR /usr/src

RUN wget https://github.com/openresty/headers-more-nginx-module/archive/v0.38.tar.gz && \
    tar xvzf v0.38.tar.gz

# Clone and install ModSecurity
# Pinning modsec due to response being cut off in newest modsec
#  https://github.com/owasp-modsecurity/ModSecurity-nginx/issues/336
RUN git clone --depth 1 --branch v3.0.13 --single-branch https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install && \
    cd ..

# Get Nginx version and source
RUN NGINX_VERSION=$(nginx -v 2>&1 | cut -d '/' -f 2) && \
    wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
    tar zxvf nginx-${NGINX_VERSION}.tar.gz


# Clone ModSecurity-nginx connector
RUN git clone --depth 1 --branch v1.0.3 --single-branch https://github.com/SpiderLabs/ModSecurity-nginx.git

# Compile Nginx with ModSecurity module
RUN NGINX_VERSION=$(nginx -v 2>&1 | cut -d '/' -f 2) && \
    cd nginx-${NGINX_VERSION} && \
    ./configure --with-compat --add-dynamic-module=../ModSecurity-nginx --add-dynamic-module=../headers-more-nginx-module-0.38 && \
    make modules && \
    mkdir -p /etc/nginx/modules/ && \
    cp objs/*.so /etc/nginx/modules


EXPOSE 80
STOPSIGNAL SIGTERM
CMD nginx -g 'daemon off;'
