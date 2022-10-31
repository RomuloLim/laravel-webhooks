#!/bin/bash

# Remove old log files
rm -rf /home/LogFiles/execContainer.log
rm -rf /home/LogFiles/cron.log

exec 1>> /home/LogFiles/execContainer.log 2>&1
cat >/etc/motd <<EOL
  _____                               
  /  _  \ __________ _________   ____  
 /  /_\  \\___   /  |  \_  __ \_/ __ \ 
/    |    \/    /|  |  /|  | \/\  ___/ 
\____|__  /_____ \____/ |__|    \___  >
        \/      \/                  \/ 
LARAVEL WEBHOOKS   -   APP SERVICE ON LINUX

PHP version : `php -v | head -n 1 | cut -d ' ' -f 2`
EOL
cat /etc/motd

# Get environment variables to show up in SSH session
eval $(printenv | sed -n "s/^\([^=]\+\)=\(.*\)$/export \1=\2/p" | sed 's/"/\\\"/g' | sed '/=/s//="/' | sed 's/$/"/' >> /etc/profile)

containerPath="/home/site/wwwroot"
appPath="/var/www"

echo "Verifying if exists a docker folder in container path"
if [ ! -d "$containerPath/docker" ]; then
  echo "Docker folder not exists, move .docker folder to app path"
  mv $appPath/.docker $containerPath/docker
else
  echo "Docker folder exists"
  echo "Updating docker folder"
  rsync -rtvu $appPath/.docker/ $containerPath/docker/
fi

echo "Docker folder found in container path"
echo "Link nginx config files"
ln -sfn $containerPath/docker/nginx/nginx-default.conf /etc/nginx/sites-enabled/default
ln -sfn $containerPath/docker/nginx/nginx.conf /etc/nginx/conf.d/custom.conf
ln -sfn $containerPath/docker/nginx/gzip.conf /etc/nginx/conf.d/gzip.conf

echo "Link php-fpm config files"
ln -sfn $containerPath/docker/php/php-fpm/custom.ini /usr/local/etc/php/conf.d/custom.ini
ln -sfn $containerPath/docker/php/php-fpm/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini
ln -sfn $containerPath/docker/php/php-fpm/www.conf /usr/local/etc/php/pool.d/www.conf

echo "Add jobs on crontab"
crontab /home/site/wwwroot/docker/cron/crontab
crontab -l

echo "link supervisor file"
ln -sfn $containerPath/docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
ln -sfn $containerPath/docker/supervisor/laravel-workers.conf /etc/supervisor/conf.d/laravel-workers.conf

echo "veryfy if .env file exists in /home/site/wwwroot"
if [ -f "$containerPath/.env" ]; then
  echo ".env file already exists in /home/site/wwwroot"
  echo "create link to .env file"
  ln -sfn $containerPath/.env $appPath/.env
 else
  echo ".env file not exists in /home/site/wwwroot"
  echo "Creating .env file"
  cp -f .env.example $containerPath/.env
  echo "create link to .env file"
  ln -sfn $containerPath/.env $appPath/.env
  echo "Generate key in .env file"
  php artisan key:generate
fi

echo "storage link"
php artisan storage:link

echo "artisan config clear"
php artisan config:clear

echo "artisan optimize clear"
php artisan optimize:clear

echo "Configuring SSL to Nginx"

echo "Copying SSL from Azure"
cp /var/ssl/private/*.p12 /etc/nginx/ssl/ssl.p12

echo "Starting services..."

echo "Starting SSH server"
service ssh start

echo "Starting cron"
service cron start

echo "Starting supervisord"
supervisord -n -c /etc/supervisor/supervisord.conf