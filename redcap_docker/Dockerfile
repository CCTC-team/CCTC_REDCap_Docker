FROM php:8.2.28-apache

# REDCap version must be provided (e.g., 15.5.36)
ARG REDCAP_VERSION
RUN test -n "${REDCAP_VERSION}" || (echo "ERROR: REDCAP_VERSION build arg is required" && exit 1)

# Install system dependencies (single layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    default-mysql-client \
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
COPY redcap_docker/php.ini /usr/local/etc/php/php.ini
RUN echo 'sendmail_path = "/usr/bin/mhsendmail --smtp-addr=mailhog:1025"' >> /usr/local/etc/php/php.ini

# Generate self-signed SSL certificate (avoids committing private keys to git)
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/mycert.key \
    -out /etc/ssl/certs/mycert.crt \
    -subj "/C=UK/ST=Cambridge/L=Cambridge/O=CCTC/OU=Programming/CN=localhost"

# Enable Apache modules and SSL
RUN a2enmod rewrite ssl socache_shmcb && \
    sed -i '/SSLCertificateFile.*snakeoil\.pem/c\SSLCertificateFile /etc/ssl/certs/mycert.crt' /etc/apache2/sites-available/default-ssl.conf && \
    sed -i '/SSLCertificateKeyFile.*snakeoil\.key/c\SSLCertificateKeyFile /etc/ssl/private/mycert.key' /etc/apache2/sites-available/default-ssl.conf && \
    a2ensite default-ssl

# Copy REDCap source into the image (context must be the parent redcap_cypress_docker/ dir)
COPY ../redcap_source/ /var/www/html/

# Fail early if REDCap source code is missing from redcap_source/
RUN test -f /var/www/html/redcap_connect.php || \
    (echo "ERROR: REDCap source code not found in redcap_source/. Download it before building." && exit 1)

# Ensure necessary directories exist with proper permissions
RUN mkdir -p /var/www/html/redcap_file_repository && \
    chown -R www-data:www-data /var/www/html/redcap_file_repository

# Copy entrypoint and supporting files
COPY redcap_docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

COPY redcap_docker/database.php /usr/local/share/redcap/database.php.template
COPY redcap_docker/CreateUsers.sql /usr/local/share/redcap/CreateUsers.sql

EXPOSE 80 443 8443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
