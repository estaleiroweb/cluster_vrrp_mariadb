#!/bin/bash
# https://mariadb.com/products/maxscale/
# https://mariadb.com/products/enterprise/

. $(dirname $0)/common.sh

cp -pf ./conf/maxscale/maxscale.cnf /etc/
replace_vars /etc/maxscale.cnf

systemctl enable maxscale
systemctl restart maxscale
systemctl --no-pager status maxscale

# admin:mariadb
# cat /var/lib/maxscale/passwd | jq .

# curl -u admin:mariadb http://192.168.1.251:8989/v1/maxscale | jq .
# curl -u admin:mariadb http://192.168.1.251:8989/v1/servers | jq .
