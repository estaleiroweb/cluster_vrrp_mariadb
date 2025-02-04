#!/bin/bash

# VRRP samples: /usr/share/doc/keepalived/samples/

# 10:56
# https://www.youtube.com/watch?v=hPfk0qd4xEY&ab_channel=TechnoTim

. $(dirname $0)/common.sh

cp -pf ./vrrp.sh /usr/local/bin/vrrp
cp -pf ./conf/keepalived/keepalived.conf /etc/keepalived/
replace_vars /etc/keepalived/keepalived.conf

modprobe ip_vs
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
echo -e "ip_vs\nip_vs_rr\nip_vs_wrr\nip_vs_sh" >>/etc/modules
lsmod | grep ip_vs # checar se módulos IPVS estão carregados
# ip_vs_sh               12288  0
# ip_vs_wrr              12288  0
# ip_vs_rr               12288  0
# ip_vs                 221184  6 ip_vs_rr,ip_vs_sh,ip_vs_wrr
# nf_conntrack          196608  1 ip_vs
# nf_defrag_ipv6         24576  2 nf_conntrack,ip_vs
# libcrc32c              12288  4 nf_conntrack,btrfs,raid456,ip_vs

### Copie keepalived/keepalived.conf de cada nó para /etc/keepalived

systemctl enable keepalived
systemctl restart keepalived
ipvsadm -L -n
