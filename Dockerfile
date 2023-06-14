FROM ubuntu:jammy as build

WORKDIR /

# install varnish 6.0-lts dependencies
RUN apt-get update && \
    apt-get install -y curl gnupg2 && \
    curl -L https://packagecloud.io/varnishcache/varnish60lts/gpgkey | apt-key add - && \
    echo "deb https://packagecloud.io/varnishcache/varnish60lts/ubuntu/ jammy main" | tee /etc/apt/sources.list.d/varnish-cache.list && \
    apt-get update && \
    apt-get install -y libgetdns-dev varnish=6.0.11-1~jammy varnish-dev=6.0.11-1~jammy

# install varnish-modules
RUN apt-get install -y git automake autoconf libtool python3 make docutils-common && \
    git clone -b 6.0-lts https://github.com/varnish/varnish-modules.git && \
    cd /varnish-modules && \
    ./bootstrap && \
    ./configure --prefix=/build && \
    make  && \
    make install

# install vmod-basicauth
COPY vmod-basicauth-1.9/ /vmod-basicauth
RUN  cd /vmod-basicauth && \
    autoreconf -f -i && \
    ./configure --with-vmoddir="/build/lib/varnish/vmods" && \
    make && \
    make install

FROM ubuntu:jammy

# install varnish 6.0-lts dependencies
RUN apt-get update && \
    apt-get install -y curl gnupg2 && \
    curl -L https://packagecloud.io/varnishcache/varnish60lts/gpgkey | apt-key add - && \
    echo "deb https://packagecloud.io/varnishcache/varnish60lts/ubuntu/ jammy main" | tee /etc/apt/sources.list.d/varnish-cache.list && \
    apt-get update && \
    apt-get install -y varnish=6.0.11-1~jammy

COPY --from=build /build/lib/varnish/vmods/ /usr/lib/varnish/vmods/
COPY --from=build /build/share/ /usr/share/

COPY default.vcl /etc/varnish/default.vcl
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
