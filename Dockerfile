FROM php:7.3.20-apache

RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

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



