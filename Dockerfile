FROM php:8.1-fpm

ENV PATH ${PATH}:/home/site/wwwroot
ENV SSH_PASSWD "root:Docker!"

# Instala expensões e dependencias do PHP
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libpq-dev \
    glibc-source \
    zlib1g-dev \
    libxml2-dev \
    libzip-dev \
    libonig-dev \
    libicu-dev \
    zip \
    curl \
    wget \
    unzip \
    nano \
    htop \
    rsync \
    openssl \
    cron \
    supervisor \
    git \
    && docker-php-ext-configure gd \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install pdo_pgsql \
    && docker-php-ext-install pdo \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install pgsql \
    && docker-php-ext-install exif \
    && docker-php-ext-install zip \
    && docker-php-source delete \
    && docker-php-ext-install opcache \
    && docker-php-ext-configure intl \
    && docker-php-ext-install intl

# Install Nginx
RUN apt-get update && \
    apt-get install nginx -y

# Clean cahe
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
RUN apt autoremove -y

# Download Composer Files
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install NodeJS
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install -y nodejs

# Configure SSH
RUN apt-get update \
    && apt-get install -y --no-install-recommends dialog \
    && apt-get update \
    && apt-get install -y --no-install-recommends openssh-server \
    && echo "$SSH_PASSWD" | chpasswd

# Creating folders for the project
RUN mkdir -p /home/LogFiles/ \
    && echo "cd /var/www/" >> /etc/bash.bashrc \
    && mkdir -p /var/www/public/tempzip \
    && rm -rf /var/www/html

COPY sshd_config /etc/ssh/
COPY ./init_container.sh /bin/init_container.sh
RUN chmod 775 /bin/init_container.sh
RUN mkdir /etc/nginx/ssl
RUN openssl dhparam -out /etc/nginx/ssl/dhparams.pem 2048

# Copy existing application directory content
COPY . /var/www

# Copy script file for initializing the container
COPY ./init_container.sh /bin/init_container.sh
RUN chmod 775 /bin/init_container.sh

WORKDIR /var/www

# Set permissions for the application
RUN chown -R www-data:www-data .
RUN find . -type f -exec chmod 664 {} \;
RUN find . -type d -exec chmod 775 {} \;
RUN chmod 777 -R storage
RUN chmod 777 -R public

# Installing composer
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Publish telescope assets
RUN php artisan vendor:publish --tag=telescope-assets --force

# Install npm packages
RUN npm install

# Uptade npm
RUN npm install -g npm

# Running npm build
RUN npm run production

EXPOSE 80 443

ENTRYPOINT ["/bin/init_container.sh"]