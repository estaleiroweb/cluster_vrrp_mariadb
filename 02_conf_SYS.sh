#!/bin/bash

. $(dirname $0)/common.sh
[ "$1" ] && NODE=$1 || NODE=1

echo "############# Config SYS node $NODE"

echo "db$NODE" >/etc/hostname
hostname db$NODE
export HOSTNAME="db$NODE"

yes y | ssh-keygen -N '' -t rsa -f ~/.ssh/id_rsa 2>/dev/null

(
	echo '127.0.0.1 localhost'
	echo
	echo '::1     ip6-localhost ip6-loopback'
	echo 'fe00::0 ip6-localnet'
	echo 'ff00::0 ip6-mcastprefix'
	echo 'ff02::1 ip6-allnodes'
	echo 'ff02::2 ip6-allrouters'
	echo
) >/etc/hosts

echo >~/.bashrc

(
	echo '# [ "$BASH" ] && [ -f ~/.bashrc ] && . ~/.bashrc'
	echo '# mesg n 2> /dev/null || true'
) >~/.profile

hostname >/var/www/html/info.html

cp -pf ./conf/{bash.bashrc,profile} /etc/

for i in $(seq 1 $MAX_NODES); do
	echo "${IP_BASE}$i $HOST_BASE$i" >>/etc/hosts
done
for i in $(seq 1 $MAX_NODES); do
	cat ~/.ssh/id_rsa.pub | sshpass -p "$PASS" ssh -o 'LogLevel=ERROR' -o 'StrictHostKeyChecking no' db$i "mkdir -p ~/.ssh; sed -ri '/= root@db$1/d' ~/.ssh/authorized_keys; cat - >> ~/.ssh/authorized_keys"
done
