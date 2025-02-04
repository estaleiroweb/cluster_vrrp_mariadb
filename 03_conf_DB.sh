#!/bin/bash

# https://mariadb.com/kb/en/getting-started-with-mariadb-galera-cluster/
# https://absam.io/blog/cluster-mariadb-galera-no-debian-ubuntu/
. $(dirname $0)/common.sh

echo "############# Config DB node $NODE"

function my() {
	if [[ $1 = $NODE ]]; then
		mysql -e "$2"
	else
		ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db$1 "mysql -e '$2'"
	fi
}
function user_replicator_master() {
	echo '  - Create replicator user'
	mysql <<<$(
		echo "CREATE OR REPLACE USER 'replicator'@'%' IDENTIFIED BY '$PASS' ;"
		echo 'GRANT REPLICATION SLAVE ON *.* TO "replicator"@"%";'
		echo 'FLUSH PRIVILEGES;'
	)
	if [ "$1" = 'force' ]; then
		mysql <<<$(
			echo 'FLUSH TABLES WITH READ LOCK;'
			echo 'SHOW MASTER STATUS;'
		)
	fi
}
function user_replicator_slave() {
	local N
	local S="$1"

	if [ ! "$1" ]; then
		N=1
		S="$NODE"
	elif [[ $1 = 1 ]]; then
		N=$MAX_NODES
	else
		N=$(($1 - 1))
	fi

	echo "  - Connect to master db$N"
	if [ "$2" = 'gtid' ]; then
		local LOG=
		local R='MASTER_USE_GTID=slave_pos'
		local BIN='bin.0001'
		local SQL="
			CHANGE MASTER TO MASTER_HOST='db$N', MASTER_USER='replicator', MASTER_PASSWORD='$PASS', MASTER_LOG_FILE='$BIN', $R;
			START SLAVE;
			SHOW SLAVE STATUS;
		"
	else
		local M=$(my $N 'SHOW MASTER STATUS;' | sed 1d)
		local BIN=$(echo $M | awk '{print $1}')
		local LOG=$(echo $M | awk '{print $2}')
		local R="MASTER_LOG_POS=$LOG" # 4 | 120
		local SQL="
			CHANGE MASTER TO MASTER_HOST='db$N', MASTER_USER='replicator', MASTER_PASSWORD='$PASS', MASTER_LOG_FILE='$BIN', $R;
			START SLAVE;
			SHOW SLAVE STATUS;
		"
	fi
	echo "====>MASTER$N: $M ($BIN,$LOG)"
	echo "=====>SQL$S: $SQL"
	my $S "$SQL"
}

if [[ $NODE == 1 ]]; then
	CONF_SEMISYNC='rpl_semi_sync_master_timeout = 10000  # Tempo de espera em milissegundos'
	CONF_SYNC='binlog-format=ROW'
else
	CONF_SEMISYNC='relay-log=/var/lib/mysql/log/mysql-relay-bin.log'
	CONF_SYNC='read_only=1'
fi

ln -sf ./db.sh /usr/local/bin/db 2>/dev/null
rm -f /etc/mysql/conf.d/{galera,sync,semisync,multimaster,gtid}.cnf 2>/dev/null
cp -pf ./conf/mysql/{50-server,auth_gssapi}.cnf /etc/mysql/mariadb.conf.d/
cp -pf ./conf/mysql/$TP.cnf /etc/mysql/conf.d/
cp -pf ./conf/mysql/bind.cnf /etc/mysql/conf.d/
replace_vars /etc/mysql/conf.d/*

systemctl enable mariadb 2>/dev/null
db recreate force

case "$TP" in
sync | semisync)
	[ "$NODE" = 1 ] && user_replicator_master force || user_replicator_slave
	;;
multimaster | gtid)
	user_replicator_master

	if [[ $NODE = $MAX_NODES ]]; then
		user_replicator_slave $NODE "$TP"
		user_replicator_slave 1 "$TP"
	elif [[ $NODE != 1 ]]; then
		user_replicator_slave $NODE "$TP"
	fi
	;;
esac

db status
