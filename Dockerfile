# TAGS
ARG phpTag=8.1-fpm
ARG nodeTag=18-bullseye
ARG composerTag=latest

##
##
FROM node:${nodeTag} as node
FROM composer:$composerTag as composer
##
##

# main image php ufficial
FROM php:$phpTag 
# 

# MORE TAGS HERE
# to changhe the app folder to something else ex /var/www/otherapp
ARG appName=app

# php
ADD ./conf/php/www.conf /usr/local/etc/php-fpm.d/www.conf
ADD ./conf/php/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
ADD ./conf/php/zend-opcache.ini /usr/local/etc/php/conf.d/docker-php-ext-opcache.ini
# RUN mkdir -p /var/log/php

RUN $(getent group www) ] || groupadd www && useradd -u 1000 -s /bin/sh www -g www

RUN mkdir -p /var/www/$appName

RUN chown www:www /var/www/$appName

# Add volumes
# VOLUME  ["/var/wwww/"]

# RUN echo '#first line \n\ #second line \n\ #third line' > /etc/apt/source.list

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qqy && apt-get install --assume-yes apt-utils
RUN  apt-get --no-install-recommends install -y \
	git \
	libzip-dev \
	libc-client-dev \
	libkrb5-dev \
	libonig-dev \
	libpng-dev \
	libjpeg-dev \
	libxml2-dev \
	libwebp-dev \
	libfreetype6-dev \
	libkrb5-dev \
	libicu-dev \
	zlib1g-dev \
	libaio1 \
	build-essential \
	unzip \
	zip \
	ffmpeg \
	libmemcached11 \
	libmemcachedutil2 \
	build-essential \
	libmemcached-dev \
	gnupg2 \
	libpq-dev \
	libpq5 \
	wget \
	libz-dev \	
	nginx \
	mariadb-server mariadb-client \
	redis-server \
	nano \
	vim \
	supervisor \
	&& apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

#**********************************************
# install instantclient libs & extension

RUN mkdir -p /opt/oracle

WORKDIR /opt/oracle

# Add volumes
# VOLUME  ["/opt/oracle"]

# Links below are latest release
# It's the Version 19.9.0.0.0(Requires glibc 2.14) by 24 of November 2020
RUN wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basic-linuxx64.zip && \ 
	wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-linuxx64.zip

RUN unzip -o instantclient-basic-linuxx64.zip -d /opt/oracle && rm -f instantclient-basic-linuxx64.zip && \
	unzip -o instantclient-sdk-linuxx64.zip -d /opt/oracle && rm -f instantclient-sdk-linuxx64.zip 

RUN ln -sv /opt/oracle/instantclient_* /opt/oracle/instantclient -f
RUN ln -s /opt/oracle/instantclient/sqlplus /usr/bin/sqlplus

# setup ld library path
RUN sh -c "echo '/opt/oracle/instantclient' >> /etc/ld.so.conf"
RUN ldconfig

# oci8
RUN docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient && docker-php-ext-install oci8 && docker-php-ext-enable oci8 

# ldap
RUN \
	apt-get update && \
	apt-get install libldap2-dev -y && \
	rm -rf /var/lib/apt/lists/* && \
	docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
	docker-php-ext-install ldap
# gd
RUN docker-php-ext-configure gd \
	--with-webp=/usr/include/ \
	--with-freetype=/usr/include/ \
	--with-jpeg=/usr/include/
RUN docker-php-ext-install gd
# imap
RUN docker-php-ext-configure imap \
	--with-kerberos \
	--with-imap-ssl
RUN docker-php-ext-install imap
# zip 
RUN docker-php-ext-configure zip
RUN docker-php-ext-install zip
# intl
RUN docker-php-ext-configure intl
RUN docker-php-ext-install intl
# pdo 
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install pdo_pgsql
RUN docker-php-ext-configure pdo_oci --with-pdo_oci=instantclient,/opt/oracle/instantclient 
RUN docker-php-ext-install pdo_oci
RUN docker-php-ext-install exif
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install soap
RUN if [ "$phpTag" = "7.4-fpm" ] ; then docker-php-ext-install json && docker-php-ext-install tokenizer ; else echo "json & tokenizer already included in php > 7.4" ; fi
RUN docker-php-ext-install opcache
RUN docker-php-ext-install ctype
# memcached
RUN pecl install memcached && docker-php-ext-enable memcached
# redis
RUN pecl install -o -f redis \
	&&  rm -rf /tmp/pear \
	&&  docker-php-ext-enable redis

# # xdebug
# RUN pecl install xdebug && docker-php-ext-enable xdebug

# add composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# add -NODE
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin
# for yarn exec because has a symlink from /opt
COPY --from=node /opt /opt

# supervisor
COPY ./conf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# NGINX
ADD ./conf/nginx/nginx.conf /etc/nginx/nginx.conf
ADD ./conf/nginx/default.conf /etc/nginx/conf.d/default.conf
# how to put logs in stderr&stdout ????
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# MARIADB
RUN mkdir -p /var/lib/mysql && mkdir -p /etc/mysql && mkdir -p /var/log/mysql && chown mysql:mysql /var/log/mysql

# adding files
COPY ./conf/mariadb/my.cnf 							/etc/mysql/my.cnf
COPY ./conf/mariadb/create_mariadb_admin_user.sh	/usr/local/bin/create_mariadb_admin_user.sh
RUN chmod +x /usr/local/bin/*

# configuration options
# Set the environment variables inside container
ENV MYSQL_ROOT_PASSWORD mypassword
ENV MYSQL_DATADIR /var/lib/mysql

ENV MYSQL_BIND_ADDRESS 0.0.0.0
ENV MYSQL_PORT 3306
# only applies when /var/lib/mysql/mysql is empty
ENV MYSQL_ADMIN_PASS mypassword
ENV MYSQL_ADMIN_USER admin
ENV MYSQL_ADMIN_HOST %
ENV MYSQL_DB_NAME laravel

# Redis
COPY ./conf/redis/redis.conf /etc/redis/redis.conf

# EXPOSE 80 $MYSQL_PORT 
# 3000 is for webpack mix watch port
# EXPOSE 80 3000

# Add volumes
# VOLUME  [ "/etc/mysql", "/var/lib/mysql"]

WORKDIR /var/www/$appName

CMD ["supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]



