#!/bin/bash

NODE=${HOSTNAME: -1}
. /root/vm/common.sh

function db_stop() {
	echo "- Node $NODE: Stop"
	if [ "$1" = 'force' ]; then
		killall -9 mariadbd 2>/dev/null
	else
		systemctl stop mariadb
	fi
}
function db_start() {
	echo "- Node $NODE: Start"
	if [ "$1" = 'force' ] && [ "$NODE" = 1 ] && [ -f /etc/mysql/conf.d/galera.cnf ]; then
		sed -ri 's/.*safe_to_bootstrap.*/safe_to_bootstrap: 1/' /var/lib/mysql/data/grastate.dat
		galera_new_cluster
	else
		systemctl start mariadb
	fi
}
function db_restart() {
	db_stop "$1"
	db_start "$1"
	db_status
}
function db_renew() {
	if [ "$NODE" = 1 ]; then
		echo "- Node $NODE: Renew"
		db_restart "$1"

		# local SEQNO=$(mysql -u root -e "SHOW STATUS LIKE 'wsrep_last_committed';" | awk '/wsrep_last_committed/ {print $2}')
		# echo "SEQNO Main: $SEQNO"
		# sed -ri 's/.*safe_to_bootstrap.*/safe_to_bootstrap: 0/' /var/lib/mysql/data/grastate.dat
		db_status
		for i in 2 3; do
			ssh db$i "db restart $1"
			# ssh db$i "sed -ri 's/.*seqno.*/seqno: $LAST_SEQNO/' /var/lib/mysql/data/grastate.dat"
		done
	else
		ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db1 'db renew'
	fi
}
function line() {
	echo
	echo '###################################################################################################'
	echo "### $1"
	echo '###################################################################################################'
}
function db_recreate() {
	db_stop $1
	if [ "$NODE" = 1 ]; then
		for i in $(seq 2 $MAX_NODES); do
			ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db$NODE "killall -9 mariadbd 2>/dev/null"
		done
	fi
	echo "- Node $NODE: Remove DB"
	rm -rf $MYDIR/*
	mkdir -p $MYDIR/{data,log,tmp}
	chown -R mysql:mysql $MYDIR/{data,log,tmp}
	chmod 750 $MYDIR/log

	echo "- Node $NODE: Create DB"
	mysql_install_db --user=mysql --basedir=/usr --datadir=$MYDIR/data > /dev/null
	# mysql_install_db --user=mysql > /dev/null
	db_start $1
	mysql -e "
		CREATE OR REPLACE DATABASE test;
		-- SHOW DATABASES;

		CREATE OR REPLACE USER '$USR'@'%' IDENTIFIED BY '$PASS' ;
		GRANT ALL PRIVILEGES ON *.* TO '$USR'@'%' WITH GRANT OPTION;

		CREATE OR REPLACE USER '$HAPROXY_USER'@'%' IDENTIFIED BY '$HAPROXY_PASS';
		GRANT USAGE ON *.* TO '$HAPROXY_USER'@'%';

		CREATE OR REPLACE USER '$MAXSCALE_USER'@'%' IDENTIFIED BY '$MAXSCALE_PASS';
		GRANT REPLICATION CLIENT, REPLICA MONITOR ON *.* TO '$MAXSCALE_USER'@'%';/*monitor */
		GRANT SUPER, RELOAD, PROCESS, FILE, SHOW DATABASES, EVENT, SET USER, READ_ONLY ADMIN ON *.* TO '$MAXSCALE_USER'@'%';
		GRANT REPLICATION SLAVE, REPLICATION SLAVE ADMIN, BINLOG ADMIN, CONNECTION ADMIN ON *.* TO '$MAXSCALE_USER'@'%';
		GRANT SELECT ON mysql.user TO '$MAXSCALE_USER'@'%';
		GRANT SELECT ON mysql.db TO '$MAXSCALE_USER'@'%';
		GRANT SELECT ON mysql.global_priv TO '$MAXSCALE_USER'@'%';
		GRANT SELECT ON mysql.tables_priv TO '$MAXSCALE_USER'@'%';
		GRANT SELECT ON mysql.roles_mapping TO '$MAXSCALE_USER'@'%';

		FLUSH PRIVILEGES;
	"
}
function db_servers() {
	echo "- Node $NODE: CREATE SERVER"
	mysql <<<$(
		echo "CREATE OR REPLACE SERVER db1 FOREIGN DATA WRAPPER mariadb OPTIONS (HOST 'db1', DATABASE 'test', USER 'admin', PASSWORD '$PASS', OWNER 'admin', PORT 3306);"
		echo "CREATE OR REPLACE SERVER db2 FOREIGN DATA WRAPPER mariadb OPTIONS (HOST 'db2', DATABASE 'test', USER 'admin', PASSWORD '$PASS', OWNER 'admin', PORT 3306);"
		echo "CREATE OR REPLACE SERVER db3 FOREIGN DATA WRAPPER mariadb OPTIONS (HOST 'db3', DATABASE 'test', USER 'admin', PASSWORD '$PASS', OWNER 'admin', PORT 3306);"
	)
}
function db_status() {
	echo -n "Status Node $NODE "

	systemctl --no-pager status mariadb

	if [ -f /etc/mysql/conf.d/galera.cnf ]; then
		line 'Galera Status'
		mysql -u root -e "SHOW VARIABLES LIKE 'wsrep_on';SHOW STATUS LIKE 'wsrep_cluster_size';SHOW STATUS LIKE 'wsrep_last_committed';SHOW VARIABLES LIKE 'auto_increment%';" | sed '/Variable_name/d;s/\t/=/'

		[ "$1" != 'all' ] && return

		line grastate.dat
		cat /var/lib/mysql/data/grastate.dat
	else
		mysql -u root -e "SHOW MASTER STATUS\GSHOW SLAVE STATUS\GSHOW VARIABLES LIKE 'log_bin'\G"

		if [ -f /etc/mysql/conf.d/semisync.cnf ]; then
			mysql -u root -e "SHOW VARIABLES LIKE 'rpl_semi_sync%'\G"
		fi

		if [ -f /etc/mysql/conf.d/gtid.cnf ]; then
			mysql -u root -e "SHOW VARIABLES LIKE 'gtid%'\G"
		fi
	fi

	[ "$1" != 'all' ] && return

	line error.log
	tail -20 /var/lib/mysql/log/error.log
}
function show_help() {
	echo "$0 <stop [force]|start|restart [force]|renew [force]|recreate [force]|status [all]|servers>"
	echo '  stop [force]      para o banco [forçado]'
	echo '  start             inicia o banco'
	echo '  restart [force]   reinicia o banco [forçado]'
	echo '  renew [force]     renova cluster [forçado]'
	echo '  recreate [force]  recria todo o banco de dados do zero [forçado]'
	echo '  staus [all]       service + detalhe simples [complemento e error.log]'
	echo '  servers           recreate servers'
	exit
}

case "$1" in
stop) db_stop $2 ;;
start) db_start $2 ;;
restart) db_restart $2 ;;
renew) db_renew $2 ;;
recreate) db_recreate $2 ;;
status) db_status $2 ;;
servers) db_servers $2 ;;
*) show_help ;;
esac

# result:
# +---------------+-------+
# | Variable_name | Value |
# +---------------+-------+
# | wsrep_on      | ON    |
# +---------------+-------+
# +--------------------+-------+
# | Variable_name      | Value |
# +--------------------+-------+
# | wsrep_cluster_size | 1     |
# +--------------------+-------+
# +--------------------------+-------+
# | Variable_name            | Value |
# +--------------------------+-------+
# | auto_increment_increment | 3     |
# | auto_increment_offset    | 3     |
# +--------------------------+-------+
