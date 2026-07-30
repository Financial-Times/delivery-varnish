#!/bin/sh

shutdown() {
	log "Stopping"
	pkill vinyld
	log "Stopped vinyld $?"
	pkill vinylncsa
	log "Stopped vinylncsa $?"
       	exit 0
}

log() {
	echo "`date +'%F %T'` $1"
}

trap 'shutdown' HUP INT QUIT KILL TERM

# Start varnish and log
log "Starting"
vinyld -pvcc_allow_inline_c=true -f /etc/vinyl-cache/default.vcl -s malloc,1024m -t 5 -p default_grace=0 &
sleep 4

vinylncsa -F '%{X-Forwarded-For}i %u %{%d/%b/%Y:%T}t %U%q %s %D "%{User-Agent}i" transaction_id=%{X-Request-Id}i %{Vinyl:handling}x' &
log "Started"

#
wait ${!}
