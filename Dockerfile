FROM php:8.2.28-apache

# REDCap version must be provided (e.g., 15.5.33)
ARG REDCAP_VERSION
RUN test -n "${REDCAP_VERSION}" || (echo "ERROR: REDCAP_VERSION build arg is required" && exit 1)

# Install system dependencies including MariaDB server and supervisor
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    default-mysql-client \
    mariadb-server \
    supervisor \
    ghostscript \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libzip-dev \
    zip \
    libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Go + mhsendmail (architecture-aware for arm64/amd64)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -Lsf "https://go.dev/dl/go1.21.6.linux-${ARCH}.tar.gz" | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go install github.com/mailhog/mhsendmail@latest && \
    cp /root/go/bin/mhsendmail /usr/bin/mhsendmail

# Install MailHog binary (architecture-aware)
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        curl -sSL -o /usr/local/bin/MailHog https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64; \
    elif [ "$ARCH" = "arm64" ]; then \
        curl -sSL -o /usr/local/bin/MailHog https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_arm; \
    fi && \
    chmod +x /usr/local/bin/MailHog

# Install phpMyAdmin
RUN curl -sSL -o /tmp/phpmyadmin.tar.gz https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.tar.gz && \
    mkdir -p /var/www/phpmyadmin && \
    tar -xzf /tmp/phpmyadmin.tar.gz -C /var/www/phpmyadmin --strip-components=1 && \
    rm /tmp/phpmyadmin.tar.gz

# Configure phpMyAdmin for auto-login to local MariaDB
RUN cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php && \
    sed -i "s|\$cfg\['Servers'\]\[\$i\]\['auth_type'\] = 'cookie';|\$cfg['Servers'][\$i]['auth_type'] = 'config';|" /var/www/phpmyadmin/config.inc.php && \
    sed -i "/\$cfg\['Servers'\]\[\$i\]\['auth_type'\]/a \$cfg['Servers'][\$i]['user'] = 'root';\n\$cfg['Servers'][\$i]['password'] = 'root';" /var/www/phpmyadmin/config.inc.php && \
    sed -i "s|\$cfg\['blowfish_secret'\] = '';|\$cfg['blowfish_secret'] = 'redcap-docker-standalone-secret-key-32chars!!';|" /var/www/phpmyadmin/config.inc.php && \
    mkdir -p /var/www/phpmyadmin/tmp && \
    chown -R www-data:www-data /var/www/phpmyadmin/tmp

# PHP extensions: mysqli
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli

# PHP extensions: GD (image processing)
RUN docker-php-ext-configure gd && \
    docker-php-ext-install -j$(nproc) gd

# PHP extensions: zip
RUN docker-php-ext-configure zip && \
    docker-php-ext-install zip

# PHP extensions: imagick (required for REDCap 13+ PDF support)
RUN pecl install imagick && \
    docker-php-ext-enable imagick

# Configure ImageMagick for PDF support
RUN sed -i 's|policy domain="coder" rights="none" pattern="PDF"|policy domain="coder" rights="read|write" pattern="PDF"|g' /etc/ImageMagick-6/policy.xml

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/php.ini

# Enable Apache modules and SSL
RUN a2enmod rewrite ssl socache_shmcb && \
    sed -i '/SSLCertificateFile.*snakeoil\.pem/c\SSLCertificateFile /etc/ssl/certs/mycert.crt' /etc/apache2/sites-available/default-ssl.conf && \
    sed -i '/SSLCertificateKeyFile.*snakeoil\.key/c\SSLCertificateKeyFile /etc/ssl/private/mycert.key' /etc/apache2/sites-available/default-ssl.conf && \
    a2ensite default-ssl

# Copy phpMyAdmin Apache VirtualHost config
COPY phpmyadmin.conf /etc/apache2/sites-enabled/phpmyadmin.conf

# Copy REDCap source into the image
COPY redcap_source/ /var/www/html/

# Ensure necessary directories exist with proper permissions
RUN mkdir -p /var/www/html/edocs \
             /var/www/html/temp \
             /var/www/html/modules \
             /var/www/html/redcap_file_repository && \
    chown -R www-data:www-data /var/www/html/edocs \
                               /var/www/html/temp \
                               /var/www/html/modules \
                               /var/www/html/redcap_file_repository

# Prepare MariaDB directories
RUN mkdir -p /var/run/mysqld && \
    chown mysql:mysql /var/run/mysqld

# Copy supervisord config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint and supporting files
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY database.php /usr/local/share/redcap/database.php.template
COPY CreateUsers.sql /usr/local/share/redcap/CreateUsers.sql

EXPOSE 80 443 1025 3306 8025 8081 8443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
