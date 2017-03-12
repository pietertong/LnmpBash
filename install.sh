#!/bin/bash
#
# 安装libraries 库
#
function install_libraries()
{
	echo "Install libraries begin..."
	sleep 10
	yum -y install gcc c++ libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel  pcre-devel
	yum -y install openssl openssl-devel libxslt-devel curl curl-devel unzip autoconf wget autoconf geoip geoip-devel
	echo "Install libraries over."
	sleep 10
}
#
# 新增用户，nginx mysql
#
function adduser(){
	users="nginx mysql"
	for user in $users
	do
		exist=`cat /etc/passwd|grep "${user}"`
		if [ "${exist}" == '' ];then
			groupadd "${user}"
			useradd -g "${user}" "${user}"
			usermod -s /sbin/nologin "${user}"
		fi
	done
}
#
# 打开端口号80 443 8080
#
function open_ports(){
	running=`firewall-cmd --state`
	if [ "${running}" != "running" ];then
		systemctl start firewalld.service
	fi
	ports="80 443 8080"
	for port in $ports
	do
		portStatus=`firewall-cmd --list-ports|grep ${port}`
		if [ "${portStatus}" == "" ];then
			portSuccess=`firewall-cmd --zone=public --add-port="${port}"/tcp --permanent`
			if [ "${portSuccess}" == "success" ];then
				systemctl restart firewalld.service
				echo "Open port ${port} success"
			fi
		else
			echo "Port ${port} already Opened!"
		fi
	done
}
function kill_process(){
	#---Kill processes of php,nginx,mysql starting#
	processes="nginx mysql php"
	for process in $processes
	do
	    #`ps aux|grep "${process}"|grep -v 'grep'|awk -F ' ' '{print $2}'|xargs kill -9`
	    pids=`ps aux|grep "${process}"|grep -v 'grep'|awk -F ' ' '{print $2}'|xargs`
	    if [ "${pids}" != '' ];then
			for pid in $pids
			do
			    kill -9 "${pid}"
			    echo "${process} was killed successfuly ,already!"
			done
	    fi
	done
}

read -p "Please select the type of web ,NGINX or APACHE ?,input 1 or 2;(1 = nginx,2 = apache):" serverType
if [ "${serverType}" ];then
	webServer=nginx
else
	echo "No used Apache soft"
	exit 1
fi
read -p "Enter the y or Y to continue:" isY
if [ "${isY}" != "Y" ] && [ "${isY}" != "y" ];then
	exit 1
fi

# #---clean up the environment ---start#
read -p "Please input 'Y' or 'y',then will check rpm tar balls which installed already!" isCheck
if [ "${isCheck}" == "Y" ] || [ "${isCheck}" == "y" ];then
	echo "mysql nginx apache php will removed..."
	rpmTarballs="mysql nginx apache php"
	for rpmTarball in rpmTarballs
	do
		checks=`rpm -qa|grep "${rpmTarball}" |xargs`
		if [ "${checks}" != '' ];then
		for check in checks
		do
		    rpm -e "${check}" --allmatches --nodeps
		done
		fi
		sleep 1
	done
	echo "rpm tar balls has removed!"
fi
kill_process
# echo "Will be installed,waiting pleases ..."
./uninstall.sh install
# #---clean up the environment ---end#


if [ `uname -m` == "x86_64" ];then
	echo "Ok"
else
	echo "These soft adapt x86_64 bit machine,please chose <centos 7.2 64 bit>"
	exit 1
fi

read -p "Please select the version of php,5.6.27 or 7.0.14 ?,input 5 or 7;(5 = 5.6.27,7 = 7.0.9):" phpVersion
if [ "${phpVersion}" == 5 ];then
	phpTarVersion="php-5.6.27.tar.gz"
	phpInstall="php-5.6.27"
	tarcmd="zxvf"
	phpmysql="--with-mysql"
else
	phpTarVersion="php-7.0.9.tar"
	phpInstall="php-7.0.9"
	tarcmd="xvf"
	phpmysql=""
fi

open_ports
# #---Clean web document root Starting#
if [ ! -d /data/www ];then
	mkdir -p /data/www
fi
# #---Clean web document root End#
adduser
# #---Add users End#
# #---Install libraries starting#
install_libraries
#---Install libraries end #

lnmp=$PWD
lnmpdir="/usr/local"
phpdir="${lnmpdir}/php"
lnmpsoftdir="${lnmp}/soft"
lnmptemplatedir="${lnmp}/templates"
tmp="${lnmp}/tmp"
rm -fr "${tmp}"
mkdir -p "${tmp}"
cd "${tmp}"

#---Install PHP Starting...

tar -"${tarcmd}" "${lnmpsoftdir}/${phpTarVersion}" && cd "${tmp}/${phpInstall}"
# Created by configure
`./configure --prefix=/usr/local/php --with-curl --with-freetype-dir \
--with-gd --with-gettext --with-iconv --with-kerberos --with-libdir=lib64 \
--with-libxml-dir --with-openssl "${phpmysql}" --with-mysqli --with-openssl \
--with-pcre-regex --with-pdo-mysql --with-pdo-sqlite --with-pear --with-png-dir \
--with-xmlrpc --with-xsl --with-zlib --enable-fpm --enable-openssl --enable-bcmath \
--enable-libxml --enable-inline-optimization --enable-gd-native-ttf --enable-mbregex \
--enable-mbstring --enable-opcache --enable-pcntl --enable-shmop --enable-soap --enable-sockets \
--enable-sysvsem --enable-xml --enable-zip --enable-maintainer-zts`

make && make install;
if [ -d "${phpdir}" ];then
	if [ ! -d /usr/local/php/etc/php-fpm.d ];then
		mkdir /usr/local/php/etc/php-fpm.d
	fi
	cp "${tmp}/php-5.6.27/sapi/fpm/init.d.php-fpm" /etc/init.d/php-fpm
	chmod a+x /etc/init.d/php-fpm
	cp "${tmp}/php-5.6.27/sapi/fpm/www.conf.in" /usr/local/php/etc/php-fpm.d/www.conf
	cp "${lnmptemplatedir}/php.ini.template.conf" /usr/local/php/lib/php.ini
	cp "${lnmptemplatedir}/php-fpm.template.conf" /usr/local/php/etc/php-fpm.conf

	cd "${tmp}" && rm -fr php-5.6.27
	echo "Install PHP Ok..."
	#----PHP extension install starting ...
	echo "PHP extension install starting ..."

	tar -zxvf "${lnmpsoftdir}/redis-2.2.8.tgz" && cd redis-2.2.8
	"${phpdir}/bin/phpize"
	./configure --with-php-config="${phpdir}/bin/php-config"
	make && make install
	cd "${tmp}" && rm -fr redis-2.2.8

	if [ "${phpVersion}" != 7 ];then
		tar -zxvf "${lnmpsoftdir}/mongo-1.6.14.tgz" && cd mongo-1.6.14
		"${phpdir}/bin/phpize"
		./configure --with-php-config="${phpdir}/bin/php-config"
		make && make install
		cd "${tmp}" && rm -fr mongo-1.6.14
	fi

	tar -zxvf "${lnmpsoftdir}/mongodb-1.2.0.tgz" && cd mongodb-1.2.0
	"${phpdir}/bin/phpize"
	./configure --with-php-config="${phpdir}/bin/php-config"
	make && make install
	cd "${tmp}" && rm -fr mongodb-1.2.0

	unzip "${lnmpsoftdir}/cphalcon-master.zip" && cd "${tmp}/cphalcon-master/build/php5/64bits"
	"${phpdir}/bin/phpize"
	./configure --with-php-config="${phpdir}/bin/php-config"
	make && make install
	cd "${tmp}" && rm -fr cphalcon-master

	gunzip "${lnmpsoftdir}/GeoLiteCity.dat.gz" && mv GeoLiteCity.dat  /usr/share/GeoIP/
	cp /usr/share/GeoIP/GeoLiteCity.dat /usr/share/GeoIP/GeoIPCity.dat;
	tar -zxvf "${lnmpsoftdir}/geoip-1.1.1.tgz" && cd geoip-1.1.1;
	"${phpdir}/bin/phpize"
	./configure --with-php-config="${phpdir}/bin/php-config"
	make && make install
	cd "${tmp}" && rm -fr geoip-1.1.1
	echo "PHP extension install ok ..."
else
	echo "PHP install failed ...!"
fi
# ----PHP extension install end ...
#---PHP Install Ok...#

#---Nginx Install Starting
echo "Nginx install starting..."
nginxdir="${lnmpdir}/nginx"
tar -zxvf "${lnmpsoftdir}/nginx-1.11.3.tar.gz" && cd nginx-1.11.3
sed -i 's/1.11.3/0.0.3/' "${lnmpsoftdir}/nginx-1.11.3/src/core/nginx.h"
sed -i 's/nginx\//IIS\//' "${lnmpsoftdir}/nginx-1.11.3/src/core/nginx.h"
./configure --prefix="${nginxdir}" --with-http_stub_status_module --with-http_ssl_module --with-http_v2_module
make && make install
if [ -d "${nginxdir}" ];then
	mkdir -p /data/www
	echo "<?php phpinfo();?>" > /data/www/index.php
	chmod 755 /data/* -R
	mkdir -p "${nginxdir}/conf/includes/certs"
	cp "${lnmptemplatedir}/nginx.template.conf" "${nginxdir}/conf/nginx.conf"
	cp "${lnmptemplatedir}/nginx.test.service.conf" "${nginxdir}/conf/includes/test.nginx.conf"
	rm -fr "${lnmpdir}/bin/nginx"
	ln -s "${nginxdir}/sbin/nginx" "${lnmpdir}/bin/nginx"
	cd "${tmp}" && rm -fr nginx-1.11.3
	nginx
	echo "Nginx install success..."
else
	echo "Nginx install faild..!"
	exit 1
fi
