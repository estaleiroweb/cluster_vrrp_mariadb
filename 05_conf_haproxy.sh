#!/bin/bash

. $(dirname $0)/common.sh

cp -pf ./conf/apache/ports.conf /etc/apache2/
cp -pf ./conf/haproxy/haproxy.cfg /etc/haproxy/
replace_vars /etc/apache2/ports.conf /etc/haproxy/haproxy.cfg

# cat /etc/apache2/ports.conf /etc/haproxy/haproxy.cfg
exit
haproxy -c -f /etc/haproxy/haproxy.cfg

# HpxWiki=/opt/haproxy-wi
# mkdir -p $HpxWiki
# git clone https://github.com/Aidaho12/haproxy-wi.git $HpxWiki
# cd $HpxWiki
# pip3 install --break-system-packages -r requirements.txt

systemctl restart apache2
systemctl enable haproxy
if [[ $NODE == 1 ]]; then
	systemctl restart haproxy
	systemctl --no-pager status haproxy
fi
# cat /etc/haproxy/haproxy.cfg | grep "bind"
# cat /etc/haproxy/haproxy.cfg | grep -A 10 "stats"

# http://192.168.1.250:9000 # com estatísticas
# http://192.168.1.250:8080 # padrão

# /etc/haproxy/haproxy.cfg /etc/haproxy/

# validar configuração

# http://192.168.1.250:9000/stats

# Fazer
# cp /root/vm/conf/apache/haproxywi.conf /etc/apache2/sites-available/haproxywi.conf
# a2ensite haproxywi.conf
# systemctl reload apache2
# a2enmod wsgi
# systemctl restart apache2

#Desfazer
# a2dissite haproxywi.conf
# rm /etc/apache2/sites-available/haproxywi.conf
# a2dismod wsgi
# systemctl restart apache2
