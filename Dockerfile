FROM php:7.3.20-apache

# RUN mkdir /www

# WORKDIR /www

VOLUME /var/www/html/

# COPY ./www/ .

COPY ../temp_www/ /var/www/html/

EXPOSE 80


