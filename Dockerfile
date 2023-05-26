FROM php:7.3.20-apache

# RUN mkdir /var/lib/mariadb

# Copy php.ini to container's configuration path
COPY php.ini /usr/local/etc/php

RUN apt update

# For MailHog to send mails
RUN apt-get install -y sendmail

RUN sendmail -bd

# Installiing mysqlite extension for php
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

RUN apt update

# Installing GD extension for PHP
RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd \
    && docker-php-ext-install -j$(nproc) gd

RUN apt update

#install some base extensions for php-zip
RUN apt-get install -y \
        libzip-dev \
        zip \
  && docker-php-ext-configure zip --with-libzip \
  && docker-php-ext-install zip

# Update the repository sources list
RUN apt-get update

# Install and run apache
RUN apt-get install -y apache2 && apt-get clean

EXPOSE 80

CMD apachectl -D FOREGROUND



