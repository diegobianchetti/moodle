#!/bin/bash
su www-data -s /bin/sh -c '/usr/bin/php /var/www/html/admin/cli/cron.php --no-keep-alive'
