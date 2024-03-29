# TAGS
ARG phpTag=8.1-fpm
ARG nodeTag=14-bullseye-slim
ARG composerTag=latest


#
FROM node:${nodeTag} as node
FROM composer:$composerTag as composer
#

## main image php ufficial
FROM php:$phpTag
##

ARG HOST_UID=1000
ENV USER=www-data

# MORE TAGS HERE
# to changhe the app folder to something else ex /var/www/otherapp
ARG appName=lab
ENV APP_NAME=${appName}

ARG WORKDIR=/var/www/${appName}
ENV DOCUMENT_ROOT=${WORKDIR}

# php.ini environment
ENV environment=development

# RUN $(getent group www) ] || groupadd www && useradd -u 1000 -s /bin/bash www -g www

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qqy && apt-get upgrade -qqy
RUN apt-get -qq install --assume-yes --no-install-recommends apt-utils
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
	# redis-server \
	libldap2-dev \
	supervisor


#**********************************************
# install instantclient libs & extension
RUN mkdir -p /opt/oracle
WORKDIR /opt/oracle
# Links below are latest release
# It's the Version 19.9.0.0.0(Requires glibc 2.14) by 24 of November 2020
RUN wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-basiclite-linuxx64.zip && \
	wget https://download.oracle.com/otn_software/linux/instantclient/instantclient-sdk-linuxx64.zip
RUN unzip -o instantclient-basiclite-linuxx64.zip -d /opt/oracle && rm -f instantclient-basiclite-linuxx64.zip && \
	unzip -o instantclient-sdk-linuxx64.zip -d /opt/oracle && rm -f instantclient-sdk-linuxx64.zip
#
RUN ln -sv /opt/oracle/instantclient_* /opt/oracle/instantclient -f
RUN ln -s /opt/oracle/instantclient/sqlplus /usr/bin/sqlplus
# setup ld library path
RUN sh -c "echo '/opt/oracle/instantclient' >> /etc/ld.so.conf"
RUN ldconfig

# oci8
RUN docker-php-ext-configure oci8 --with-oci8=instantclient,/opt/oracle/instantclient && docker-php-ext-install oci8 && docker-php-ext-enable oci8

# ldap
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ && \
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

# RUN usermod -a -G www-data www

# nginx
ADD docker/nginx.default.conf /etc/nginx/sites-enabled/default
# ADD docker/nginx.conf /etc/nginx/nginx.conf

RUN rm -Rf /var/www/* && \
mkdir -p /var/www/html

RUN mkdir -p /var/www/$appName

# # Copy existing application directory contents
# RUN chown www:www /var/www/$appName
# RUN mkdir -p /var/cache/nginx
# RUN chown www-data:www-data /var/cache/nginx

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log


# php
COPY ./docker/app.ini /usr/local/etc/php/conf.d/app.ini
RUN mv "$PHP_INI_DIR/php.ini-${environment}" "$PHP_INI_DIR/php.ini"

#unix socket connection?
ADD ./docker/zz-docker.conf /usr/local/etc/php-fpm.d/zz-docker.conf
RUN sed -E -i -e 's#listen = 127.0.0.1:9000#;listen = /var/run/php-fpm.sock#' /usr/local/etc/php-fpm.d/www.conf

# add composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

# add -node
# COPY --from=node /usr/lib /usr/lib
# COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin
COPY --from=node /opt /opt

# supervisor
ADD docker/supervisor.conf /etc/supervisor/supervisord.conf

# redis
# ADD docker/redis.conf /etc/redis/redis.conf


WORKDIR /var/www/$appName
ENV APP_NAME=$appName

COPY ./src*/ /var/www/$appName/

COPY ./docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s /usr/local/bin/docker-entrypoint.sh /

ENTRYPOINT ["docker-entrypoint.sh"]

RUN usermod -u ${HOST_UID} www-data
RUN groupmod -g ${HOST_UID} www-data
RUN chmod -R 755 $WORKDIR
RUN chown -R www-data:www-data $WORKDIR

EXPOSE 80

CMD [ "docker-entrypoint" ]