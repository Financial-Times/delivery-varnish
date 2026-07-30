FROM ubuntu:jammy AS build

ARG VINYL_VERSION=9.0.1
ARG VINYL_MODULES_VERSION=0.28.0

WORKDIR /

# Vinyl Cache 9 is not yet available from the package source used by the
# Varnish 6 image. Build the supported Vinyl release once, then use its
# headers, pkg-config metadata and vmodtool to build VMODs with the exact same
# ABI as the daemon that loads them.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        autotools-dev \
        ca-certificates \
        cpio \
        curl \
        git \
        libedit-dev \
        libjemalloc-dev \
        libncurses-dev \
        libpcre2-dev \
        libtool \
        make \
        pkg-config \
        python3 \
        python3-docutils \
        python3-sphinx && \
    rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --silent --show-error \
        "https://vinyl-cache.org/downloads/vinyl-cache-${VINYL_VERSION}.tgz" \
        --output /vinyl-cache.tgz && \
    tar -xzf /vinyl-cache.tgz && \
    cd "/vinyl-cache-${VINYL_VERSION}" && \
    ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install

# Release 0.28.0 is the VMOD release matched to Vinyl Cache 9. Its source
# predates the Vinyl rename, so update its Autotools macro, pkg-config and
# private-header names before generating the build system. Do not build a VMOD
# against distribution headers: Vinyl rejects modules built for a different ABI.
RUN git clone --branch "${VINYL_MODULES_VERSION}" --depth 1 \
        https://github.com/varnish/varnish-modules.git /varnish-modules && \
    cd /varnish-modules && \
    sed -i \
        -e 's/varnishapi/vinylapi/g' \
        -e 's/cache_varnishd/cache_vinyld/g' \
        -e 's/VARNISHAPI/VINYLAPI/g' \
        -e 's/VARNISH_/VINYL_/g' \
        -e 's/varnish_/vinyl_/g' \
        bootstrap configure.ac src/Makefile.am src/vmod_bodyaccess.c \
        src/vmod_xkey.c src/xkey.vsc && \
    ./bootstrap && \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure --prefix=/usr/local && \
    make -j"$(nproc)" && \
    make install

# vmod-basicauth v2.2 is maintained upstream and implements the same
# basicauth.match VCL API against htpasswd files. Its pinned acvmod submodule
# supplies the Autotools rules, so initialize it over HTTPS rather than its
# legacy git:// URL. Pin the immutable release commit rather than carrying a
# locally patched, security-sensitive C VMOD.
RUN git clone --branch v2.2 --depth 1 https://git.gnu.org.ua/vmod-basicauth.git /vmod-basicauth && \
    cd /vmod-basicauth && \
    test "$(git rev-parse HEAD)" = ce733a3f8c76ec83b44fe05184cf52150ef5faf3 && \
    git submodule set-url acvmod https://git.gnu.org.ua/acvmod.git && \
    git submodule update --init --depth 1 && \
    autoreconf -f -i && \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig ./configure --with-vmoddir=/usr/local/lib/vinyl-cache/vmods && \
    make -j"$(nproc)" && \
    make install

FROM ubuntu:jammy

# Keep only the runtime libraries required by the source-built Vinyl binaries
# and VMODs. The daemon and all generated modules are copied from the build
# stage so their ABI always remains in lockstep.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libc6-dev \
        libedit2 \
        libjemalloc2 \
        libncurses6 \
        libpcre2-8-0 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/ /usr/local/

COPY default.vcl /etc/vinyl-cache/default.vcl
COPY start.sh /start.sh

# Vinyl Cache is built from source into /usr/local, so refresh the dynamic
# linker cache before vinylncsa or the VMODs load libvinylapi at runtime.
RUN ldconfig && chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
