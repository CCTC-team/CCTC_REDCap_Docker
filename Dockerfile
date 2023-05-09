FROM php:7.3.20-apache

# RUN mkdir /www

# WORKDIR /www

VOLUME /var/www/html/

# COPY ./www/ .

COPY ./www/ /var/www/html/

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



