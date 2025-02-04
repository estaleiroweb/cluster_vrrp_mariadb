#!/bin/bash

. $(dirname $0)/common.sh

cp -pf ./sync.sh /usr/local/bin/
replace_vars /usr/local/bin/sync.sh

nohup /usr/local/bin/sync.sh > /dev/null 2>&1 &

crontab -r
(crontab -l 2>/dev/null; echo "
@reboot nohup /usr/local/bin/sync.sh > /dev/null 2>&1 &

") | crontab -
