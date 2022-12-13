#!/bin/sh

# cd /var/www/$APP_NAME non funziona

# php artisan migrate:fresh --seed
# php artisan cache:clear
# php artisan route:cache

/usr/bin/supervisord -c /etc/supervisor/supervisord.conf