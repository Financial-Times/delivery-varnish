#!/bin/sh

authinit() {
	for i in 0 1 2 3 4 5 6 7 8 9
	do
		curl -f -s "$ETCD_HOST/v2/keys$ETCD_CONFIG_KEY" >/tmp/t
		# Check the file is non-zero size
		if [ -s /tmp/t ]
		then
			log "Got value for $ETCD_CONFIG_KEY, setting /.htpasswd"
			cat /tmp/t | jq -r .node.value | tr ',' '\n' > /.htpasswd;
			rm /tmp/t;
			return
		else
			log "Failed fetching $ETCD_CONFIG_KEY from etcd ($i)"
			sleep 5
			continue
		fi
	done
	log "Failed fetching $ETCD_CONFIG_KEY from etcd, starting with empty '/.htpasswd'"
}

shutdown() {
	log "Stopping"
	pkill varnishd
	log "Stopped varnishd $?"
	pkill varnishncsa
	log "Stopped varnishncsa $?"
       	exit 0
}

watch() {
	while true; do
		curl -f -s "$ETCD_HOST/v2/keys$ETCD_CONFIG_KEY?wait=true" >/tmp/t && cat /tmp/t | jq -r .node.value | tr ',' '\n' > /.htpasswd;
		# sleep in case val doesn't exist/etcd not running etc
		sleep 5;
	done
}

log() {
	echo "`date +'%F %T'` $1"
}

trap 'shutdown' HUP INT QUIT KILL TERM

# Try and get intial auth value
authinit

# Convert environment variables in the conf to fixed entries
for name in VARNISH_BACKEND_PORT VARNISH_BACKEND_HOST HOST_HEADER CONTENT_NOTIFICATIONS_PUSH_PORT LIST_NOTIFICATIONS_PUSH_PORT
do
    eval value=\$$name
    sed -i "s/$name/${value}/g" /etc/varnish/default.vcl
done

# Start varnish and log
log "Starting"
varnishd -f /etc/varnish/default.vcl -s malloc,1024m -t 5 -p default_grace=0 &
sleep 4

varnishncsa -F '%{X-Forwarded-For}i %u %{%d/%b/%Y:%T}t %U%q %s %D "%{User-Agent}i" tid="%{X-Request-Id}i" %{Varnish:handling}x' &
log "Started"

# watch for changes and update
watch & wait ${!}
