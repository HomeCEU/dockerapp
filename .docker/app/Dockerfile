ARG PHP_VERSION=7.3

FROM php:${PHP_VERSION}-apache-stretch 

# ARG's above FROM are reset after FROM
ARG HOST_UID=1000
# Surpresses debconf complaints of trying to install apt packages interactively
ARG DEBIAN_FRONTEND=noninteractive

# https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/bin/

# https://stackoverflow.com/a/58694421/2683059
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
ENV PATH "$PATH:/var/www/html/vendor/bin"

COPY site.conf /etc/apache2/sites-enabled/

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
        wkhtmltopdf \
    # Apache
    && a2enmod rewrite \
    && a2enmod headers \
    # PHP Extensions
    && install-php-extensions gd xdebug pdo_mysql \
    # Cleanup
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* /tmp/.htaccess \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete \
    && find /var/log -type f | while read f; do echo -n '' > ${f}; done \
    && rm -rf /run/httpd/* /tmp/httpd* \
    # Configure Host User
    && useradd -u ${HOST_UID} hostuser \
    && usermod -a -G www-data hostuser \
    && usermod -a -G hostuser www-data \