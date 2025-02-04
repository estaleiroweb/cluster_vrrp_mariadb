NODE=${HOSTNAME: -1}
IP_BASE='192.168.1.25'
HOST_BASE='db'
IP="$IP_BASE$NODE"
IPV="${IP_BASE}0"
HOST="$HOST_BASE$NODE"

USR=admin
PASS=senha

HAPROXY_USER=haproxy
HAPROXY_PASS=senha

HAPROXY_ADMIN_USER=admin
HAPROXY_ADMIN_PASS=senha

MAXSCALE_USER=maxscale
MAXSCALE_PASS=$(maxpasswd senha)

KEEPALIVE_AUTH_TYPE=PASS
KEEPALIVE_AUTH_PASS=123456

KEEPALIVE_PRIORITY=$((200 - ($NODE -1 )*50))
MAX_NODES=3
MYDIR=/var/lib/mysql
TP=sync
# galera: cluster
# sync: Replicação Assíncrona (Master-Slave)
# semisync: Replicação Semissíncrona
# multimaster: Replicação Multimaster Assíncrona ou Circular
# gtid: GTID (Global Transaction ID)

cd "$(dirname $0)"
ALL_NODES=
for i in $(seq 1 $MAX_NODES); do
	ALL_NODES="$ALL_NODES,$HOST_BASE$i"
done
ALL_NODES=${ALL_NODES:1}

function replace_vars() {
	local FILE=
	local i

	while [[ ${#} != 0 ]]; do
		FILE="$1"
		shift
		[ ! -f "$FILE" ] && continue
		echo -n "Replace $FILE:"
		for i in $(egrep -o '<[A-Z_]+>' "$FILE" | sed 's/[<>]//g' | sort -u); do
			echo -n " $i"
			sed -ri "s/<$i>/${!i}/" "$FILE"
		done
		echo
	done
}
