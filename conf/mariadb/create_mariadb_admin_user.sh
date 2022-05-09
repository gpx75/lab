#!/bin/bash

/usr/bin/mysqld_safe > /dev/null 2>&1 &

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MariaDB service startup"
    sleep 5
    mysql -uroot -e "status" > /dev/null 2>&1
    RET=$?
done


PASS=${MYSQL_ADMIN_PASS:-$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c${1:-24};echo;)}
_word=$( [ ${MYSQL_ADMIN_PASS} ] && echo "preset" || echo "random" )
echo "=> Creating MariaDB admin user with ${_word} password"

mysql -uroot -e "CREATE USER '$MYSQL_ADMIN_USER'@'$MYSQL_ADMIN_HOST' IDENTIFIED BY '$PASS'"
mysql -uroot -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_ADMIN_USER'@'$MYSQL_ADMIN_HOST' WITH GRANT OPTION"
mysql -uroot -e " CREATE IF NOT EXISTS '$MYSQL_DB_NAME'"
# mysqladmin -uroot create $MYSQL_DB_NAME

echo "=> Done!"

mysqladmin -uroot shutdown