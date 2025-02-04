#!/bin/bash

apt update
apt upgrade -y
apt install -y \
	software-properties-common lsb-release apt-transport-https \
	ca-certificates \
	curl wget gpg \
	zip unzip \
	tzdata

ln -fs /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

echo | openssl s_client -showcerts -connect www.google.com:443 >/usr/local/share/ca-certificates/my-ca.crt
update-ca-certificates

curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash

apt update

apt install -y \
	locate tree vim nmap \
	sshpass rsync inotify-tools \
	git \
	apache2 \
	iproute2 net-tools iputils-ping iputils-tracepath \
	keepalived ipvsadm libipset13 \
	haproxy hatop \
	python3-pip \
	python3-dev \
	python3-mysql.connector \
	python3-decorator \
	python3-paramiko \
	python3-pandas-flavor python3-pandas-lib python3-pandas python3-geopandas \
	python3-numpy python3-numpydoc \
	mariadb-server mariadb-client \
	mariadb-plugin-connect \
	mariadb-plugin-gssapi-client mariadb-plugin-gssapi-server \
	mariadb-plugin-mroonga \
	mariadb-plugin-oqgraph \
	mariadb-plugin-rocksdb \
	mariadb-plugin-spider \
	mariadb-plugin-s3 \
	mariadb-backup \
	mariadb-test-data mariadb-test \
	maxscale \
	libapache2-mod-wsgi-py3 \
	libmysqlclient-dev libssl-dev

apt clean all

updatedb
