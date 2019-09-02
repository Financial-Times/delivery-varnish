FROM alpine:3.9

ENV VARNISHSRC=/usr/include/varnish VMODDIR=/usr/lib/varnish/vmods

RUN apk --update add  varnish-dev git automake autoconf libtool python make py-docutils curl jq && apk add --repository http://dl-cdn.alpinelinux.org/alpine/v3.8/main/ varnish~=6.0.2-r0 && \
  cd / && \
  git clone https://github.com/varnish/varnish-modules.git && \
  cd varnish-modules && \
  git checkout  0d555b627333cd9190a40870f380ace5664f6d0d && \
  ./bootstrap && \
  ./configure && \
  make  && \
  make install && \
  cd / && \
  git clone http://git.gnu.org.ua/repo/vmod-basicauth.git && \
  cd vmod-basicauth && \
  git checkout ef9772ebab0c3aeaf6ad9a8f843fa458d0c8397c && \
  ./bootstrap && \
  ./configure && \
  make && \
  make install && \
  apk del git automake autoconf libtool python make py-docutils && \
  rm -rf /var/cache/apk/* /libvmod-vsthrottle /vmod-basicauth

COPY default.vcl /etc/varnish/default.vcl
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
