#!/bin/sh

shutdown() {
	log "Stopping"
	pkill varnishd
	log "Stopped varnishd $?"
	pkill varnishncsa
	log "Stopped varnishncsa $?"
       	exit 0
}

log() {
	echo "`date +'%F %T'` $1"
}

trap 'shutdown' HUP INT QUIT KILL TERM

<<<<<<< HEAD
=======
# Try and get intial auth value
authinit

# Convert environment variables in the conf to fixed entries
for name in VARNISH_BACKEND_PORT VARNISH_BACKEND_HOST HOST_HEADER LIST_NOTIFICATIONS_PUSH_PORT CONTENT_NOTIFICATIONS_PUSH_API_PORT
do
    eval value=\$$name
    sed -i "s/$name/${value}/g" /etc/varnish/default.vcl
done

>>>>>>> master
# Start varnish and log
log "Starting"
varnishd -pvcc_allow_inline_c=true -f /etc/varnish/default.vcl -s malloc,1024m -t 5 -p default_grace=0 &
sleep 4

varnishncsa -F '%{X-Forwarded-For}i %u %{%d/%b/%Y:%T}t %U%q %s %D "%{User-Agent}i" transaction_id=%{X-Request-Id}i %{Varnish:handling}x' &
log "Started"

#
wait ${!}
