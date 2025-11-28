FROM --platform=linux/amd64 php:8.2.28-apache

# Copy php.ini to container's configuration path
COPY php.ini /usr/local/etc/php/php.ini

RUN apt update

# Configure Sendmail in the PHP Container
RUN apt-get update &&\
    apt-get install --no-install-recommends --assume-yes --quiet ca-certificates curl git &&\
    rm -rf /var/lib/apt/lists/*

RUN curl -Lsf 'https://storage.googleapis.com/golang/go1.8.3.linux-amd64.tar.gz' | tar -C '/usr/local' -xvzf -

ENV PATH /usr/local/go/bin:$PATH

RUN go get github.com/mailhog/mhsendmail

RUN cp /root/go/bin/mhsendmail /usr/bin/mhsendmail

RUN echo 'sendmail_path = /usr/bin/mhsendmail --smtp-addr mailhog:1025' >> /usr/local/etc/php/php.ini

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

# Install some base extensions for php-zip
RUN apt-get install -y \
        libzip-dev \
        zip \
  && docker-php-ext-configure zip \
  && docker-php-ext-install zip

# Update the repository sources list
RUN apt-get update

# Install imagick extension in php for REDCap 13.1.20
RUN apt-get update; \
    apt-get install -y libmagickwand-dev; \
    pecl install imagick; \
    docker-php-ext-enable imagick;

# Change policy.xml (located at /etc/ImageMagick-6/), change PDF rights to 'read'
RUN  sed -i 's|policy domain="coder" rights="none" pattern="PDF"|policy domain="coder" rights="read" pattern="PDF" |g' /etc/ImageMagick-6/policy.xml


# Enable SSL and add certificates
RUN a2enmod rewrite && a2enmod ssl && a2enmod socache_shmcb
RUN sed -i '/SSLCertificateFile.*snakeoil\.pem/c\SSLCertificateFile \/etc\/ssl\/certs\/mycert.crt' /etc/apache2/sites-available/default-ssl.conf && sed -i '/SSLCertificateKeyFile.*snakeoil\.key/cSSLCertificateKeyFile /etc/ssl/private/mycert.key\' /etc/apache2/sites-available/default-ssl.conf
RUN a2ensite default-ssl
RUN apt-get update && apt-get upgrade -y

EXPOSE 80

CMD apachectl -D FOREGROUND