ARG PHP_VERSION=7.3

FROM php:${PHP_VERSION}-apache-stretch 

# Surpresses debconf complaints of trying to install apt packages interactively
ARG DEBIAN_FRONTEND=noninteractive

# https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

# https://stackoverflow.com/a/58694421/2683059
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

COPY .docker/app/site.conf /etc/apache2/sites-enabled/

RUN apt clean -y \
    && rm -f /etc/apache2/sites-enabled/000-default.conf \
    && apt update -y \
    && apt upgrade -y \
    && apt install --no-install-recommends -yq \
        apt-utils \
        curl \
        git \
        memcached \
    # mysql-client stops working in debian 10
    # use default-mysql-client instead if you upgrade
        mysql-client \ 
        sudo \
        vim \
        wget \
        # packages required to generate pdf
        xauth \
        xvfb \
        openssl \
        build-essential \
        xorg \
        libssl1.0-dev \
    # zip is required for composer
        zip unzip \
        && wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.4/wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
        && tar xvJf wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
        && cp wkhtmltox/bin/wkhtmlto* /usr/bin/ \
        && rm wkhtmltox-0.12.4_linux-generic-amd64.tar.xz \
        && rm -rf wkhtmltox \
    # Apache
    && a2enmod rewrite \
    && a2enmod headers \
    # PHP Extensions
    && install-php-extensions gd xdebug pdo_mysql zip

WORKDIR /var/www/html
COPY ./app/composer.json ./
COPY ./app/composer.lock ./
RUN composer install --no-scripts --no-autoloader --no-interaction --no-dev
COPY ./app ./
RUN composer dump-autoload --optimize && \
    composer run-script post-install-cmd
ENV PATH "$PATH:/var/www/html/vendor/bin"

    # Cleanup
RUN apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* /tmp/.htaccess \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete \
    && find /var/log -type f | while read f; do echo -n '' > ${f}; done \
    && rm -rf /run/httpd/* /tmp/httpd* \
    && rm -rf /composer/cache