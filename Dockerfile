FROM alpine:3.7

ENV VARNISHSRC=/usr/include/varnish VMODDIR=/usr/lib/varnish/vmods

RUN apk --update add varnish varnish-dev git automake autoconf libtool python make py-docutils curl jq && \
  cd / && \
  git clone https://github.com/varnish/varnish-modules.git && \
  cd varnish-modules && \
  git checkout 19b479ac756645b5a6fa79d398329f4a37cca5c8 && \
  ./bootstrap && \
  ./configure && \
  make && \
  make install && \
  cd / && \
  git clone http://git.gnu.org.ua/repo/vmod-basicauth.git && \
  cd vmod-basicauth && \
  git checkout a9a5d76f3fdac0ddbf76f7d021be3c95b7bfbdef && \
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
