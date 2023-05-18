FROM php:7.3.20-apache

# RUN mkdir /www

# WORKDIR /www

# VOLUME /var/www/html/
# COPY ./www/ /var/www/html/

# COPY ./www/ .

# COPY php.ini /etc/


RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# this image leads to two conflicting installations of PHP in a single image, which is almost certainly not the intended outcome.
# RUN rm /etc/apt/preferences.d/no-debian-php

# RUN apt-get -y update
# RUN apt-get -y upgrade
# # RUN apt-get install -y sqlite libsqlite-dev
# RUN apt-get install php-mysqli
# # RUN service apache2 restart
# RUN mkdir /db

# Update the repository sources list
RUN apt-get update

# Install and run apache
RUN apt-get install -y apache2 && apt-get clean

#ENTRYPOINT ["/usr/sbin/apache2", "-k", "start"]


#ENV APACHE_RUN_USER www-data
#ENV APACHE_RUN_GROUP www-data
#ENV APACHE_LOG_DIR /var/log/apache2

EXPOSE 80
CMD apachectl -D FOREGROUND



