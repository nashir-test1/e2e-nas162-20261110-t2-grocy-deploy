FROM node:24-bookworm-slim AS assets
WORKDIR /src
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*
COPY package.json yarn.lock .yarnrc ./
RUN yarn install --frozen-lockfile --non-interactive --production=true

FROM composer:2 AS composer

FROM php:8.5-apache
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git unzip libfreetype6-dev libicu-dev libjpeg62-turbo-dev \
        libonig-dev libpng-dev libsqlite3-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j2 gd intl mbstring pdo_sqlite \
    && rm -rf /var/lib/apt/lists/*
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
WORKDIR /var/www/html
COPY . .
COPY --from=assets /src/public/packages ./public/packages
RUN COMPOSER_ALLOW_SUPERUSER=1 composer install \
        --no-dev --prefer-dist --no-progress --no-interaction --optimize-autoloader \
    && a2enmod rewrite \
    && sed -i 's/^Listen 80$/Listen 8080/' /etc/apache2/ports.conf \
    && mkdir -p data \
    && chown -R www-data:www-data data
COPY deploy/apache.conf /etc/apache2/sites-available/000-default.conf
COPY deploy/entrypoint.sh /usr/local/bin/grocy-entrypoint
RUN chmod 755 /usr/local/bin/grocy-entrypoint
ENV GROCY_DATAPATH=/var/www/html/data
ENV APACHE_RUN_DIR=/tmp/apache2 \
    APACHE_PID_FILE=/tmp/apache2/apache2.pid \
    APACHE_LOCK_DIR=/tmp/apache2-lock \
    APACHE_LOG_DIR=/tmp/apache2-log
USER www-data
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD php -r 'exit(@file_get_contents("http://127.0.0.1:8080/") === false ? 1 : 0);'
ENTRYPOINT ["grocy-entrypoint"]
CMD ["apache2-foreground"]
