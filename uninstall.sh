#!/bin/bash

if [ "$1" != "install" ];then 
    echo "Before cleaning the evnironment ,please back up your data !"
    read -p "Enter the Y or y to continue:" continueY
    if [ "${continueY}" != "Y" ]  && [ $"{continueY}" != "y" ];then
        exit 1
    fi
fi

rm -fr /data/backup

if [ ! -d /data/backup ];then
    mkdir -p /data/backup
fi

if [ ! -d /data/backup/init.d ];then
    mkdir -p /data/backup/init.d
fi

if [ ! -d /data/backup/php ];then
    mkdir -p /data/backup/php
fi

if [ ! -d /data/backup/nginx ];then
    mkdir -p /data/backup/nginx
fi

if [ ! -d /data/backup/mysqldata ];then
    mkdir -p /data/backup/mysqldata
fi

#---Copy some need backup files
cp /data/www /data/backup/ -rf &> /dev/null;
cp /etc/init.d/* /data/backup/init.d/ -rf &> /dev/null;
cp /usr/local/php/* /data/backup/php/ -rf &> /dev/null;
cp /usr/local/nginx/* /data/backup/nginx/ -rf &> /dev/null;
cp /var/lib/mysql/* /data/backup/mysqldata/* -rf &> /dev/null;

cp ./templates/rc.d.rc.local /etc/rc.d/rc.local &> /dev/null;

echo "Back up Lnmp ok!"

if [ "$1" != "install" ];then
   bash
fi
