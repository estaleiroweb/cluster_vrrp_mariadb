#!/bin/bash

function confime() {
	while true; do
		read -N 1 -s -p 'Tenha certeza que esta é a VM primária [S/n]: ' C
		C=${C^^} # Converte para maiúscula para evitar problemas com letras minúsculas
		C=$(printf "%d " "'${C:0:1}") ## converte em ASCII
		# C=${C:-S} # Se C estiver vazio, define como S

		if [ $C == 27 ] || [ $C = 78 ]; then
			echo
			echo Abort
			exit
		fi
		if [ $C = 10 ] || [ $C = 83 ]; then
			echo
			return
		fi
		echo -ne '\r'
	done
}
confime

P=$(dirname $0)
cd $P
. $P/common.sh

function exec() {
	local FILE="$1"
	local NODE="$2"

	if [ "$NODE" = 1 ]; then
		$P/${FILE}.sh $NODE
	else
		ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db$NODE "~/vm/${FILE}.sh $NODE"
	fi
}

for i in $(seq 1 $MAX_NODES); do
	echo
	echo "NODE $i"
	if [ "$i" != 1 ]; then
		ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db$i 'mkdir -p ~/vm'
		scp -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' -rpq ./* db$i:~/vm/
	fi

	# 01_install 02_conf_SYS 03_conf_DB 04_conf_VRRP 05_conf_haproxy 06_conf_sync 07_conf_maxscale
	for fn in 04_conf_VRRP 05_conf_haproxy 07_conf_maxscale; do 
		exec $fn $i
	done
	break
done
