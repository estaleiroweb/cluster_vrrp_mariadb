#!/bin/bash

NODE=${HOSTNAME: -1}

function db_stop() {
	systemctl stop keepalived
}
function db_start() {
	systemctl start keepalived
}
function db_restart() {
	db_stop
	db_start
}
function db_status() {
	lsmod | grep ip_vs # checar se módulos IPVS estão carregados
	ipvsadm -L -n      # status IP Virtual
	systemctl --no-pager status keepalived
}
function show_help() {
	echo "$0 <stop|start|restart|status>"
	exit
}

case "$1" in
stop) db_stop ;;
start) db_start ;;
restart) db_restart ;;
status) db_status ;;
*) show_help ;;
esac
