#!/bin/sh

Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
echo ""
echo "***********************************************************"
echo " Starting " $APP_NAME " Container                   "
echo "***********************************************************"

set -e


/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

