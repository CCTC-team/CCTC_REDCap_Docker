# All-in-one REDCap image: REDCap (PHP/Apache) + MariaDB + Mailhog in ONE image,
# run by supervisord. `docker run` (or a one-service compose) stands the whole
# thing up with no sidecar containers.
#
# REDCap source is baked in and writable in the container's layer (ephemeral:
# resets to pristine on recreate). The MariaDB data dir (/var/lib/mysql) can be
# backed by a named volume (cctc_mariadb_data) to persist the database.
#
# Build context MUST be the parent CCTC_REDCap_Docker/ dir so redcap_source/ is
# reachable (the bundled docker-compose.yml sets context: ..).
FROM php:8.2.30-apache

ARG REDCAP_VERSION
RUN test -n "${REDCAP_VERSION}" || (echo "ERROR: REDCAP_VERSION build arg is required" && exit 1)
# Persist the version into the runtime env so entrypoint.sh can find the SQL
# install files and stamp the version into redcap_config.
ENV REDCAP_VERSION=${REDCAP_VERSION}

# System deps: REDCap libs + MariaDB server + supervisor (in-container init).
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git \
    default-mysql-client mariadb-server \
    supervisor \
    ghostscript \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev zip \
    libmagickwand-dev \
    && rm -rf /var/lib/apt/lists/*

# Go toolchain (latest stable) -> build mhsendmail (PHP mail routing) and MailHog
# (SMTP+UI) from source so both are native-arch (MailHog ships no arm64 release
# binary). MailHog has no go.mod, so module-mode pulls *latest* transitive deps;
# several now require Go >= 1.24/1.25, so we use the newest Go to satisfy them.
RUN ARCH=$(dpkg --print-architecture) && \
    GOVER=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -n1) && \
    echo "Using ${GOVER}" && \
    curl -Lsf "https://go.dev/dl/${GOVER}.linux-${ARCH}.tar.gz" | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"
RUN go install github.com/mailhog/mhsendmail@latest && \
    cp /root/go/bin/mhsendmail /usr/bin/mhsendmail && \
    go install github.com/mailhog/MailHog@latest && \
    cp /root/go/bin/MailHog /usr/local/bin/mailhog && \
    rm -rf /root/go /root/.cache/go-build

# PHP extensions REDCap needs.
RUN docker-php-ext-install mysqli && docker-php-ext-enable mysqli
RUN docker-php-ext-configure gd && docker-php-ext-install -j"$(nproc)" gd
RUN docker-php-ext-configure zip && docker-php-ext-install zip
RUN pecl install imagick && docker-php-ext-enable imagick

# Allow ImageMagick to read/write PDFs.
RUN policy=$(find /etc/ImageMagick-* -name policy.xml 2>/dev/null | head -n1); \
    if [ -n "$policy" ]; then \
        sed -i 's#rights="none" pattern="PDF"#rights="read|write" pattern="PDF"#g' "$policy" && \
        echo "Patched ImageMagick PDF policy at $policy"; \
    else \
        echo "No ImageMagick policy.xml found; PDF coder already unrestricted"; \
    fi

# PHP config: production base + REDCap overrides (mail routed to local Mailhog).
RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY redcap_docker_aio/conf/redcap.ini /usr/local/etc/php/conf.d/zz-redcap.ini

# Self-signed cert.
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/mycert.key \
    -out /etc/ssl/certs/mycert.crt \
    -subj "/C=UK/ST=Cambridge/L=Cambridge/O=CCTC/OU=Programming/CN=localhost" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    -addext "authorityKeyIdentifier=keyid,issuer"

# Apache: rewrite + SSL.
RUN a2enmod rewrite ssl socache_shmcb && \
    sed -i '/SSLCertificateFile.*snakeoil\.pem/c\SSLCertificateFile /etc/ssl/certs/mycert.crt' /etc/apache2/sites-available/default-ssl.conf && \
    sed -i '/SSLCertificateKeyFile.*snakeoil\.key/c\SSLCertificateKeyFile /etc/ssl/private/mycert.key' /etc/apache2/sites-available/default-ssl.conf && \
    a2ensite default-ssl

# Reset the MariaDB data dir so entrypoint.sh initializes it cleanly on first
# boot (the apt package pre-seeds it; a mounted volume would otherwise shadow it).
RUN rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql /run/mysqld

# Bake the REDCap source into the image and make it writable by Apache.
COPY redcap_source/ /var/www/html/
RUN test -f /var/www/html/redcap_connect.php || \
    (echo "ERROR: REDCap source not found in redcap_source/. Download it before building." && exit 1)
RUN chown -R www-data:www-data /var/www/html

# Process supervision + boot logic.
COPY redcap_docker_aio/supervisord.conf /etc/supervisord.conf
COPY redcap_docker_aio/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY redcap_docker_aio/CreateUsers.sql /usr/local/share/redcap/CreateUsers.sql
RUN chmod +x /usr/local/bin/entrypoint.sh

# 80/443 Apache, 8443 internal SSL, 1025 SMTP, 8025 Mailhog UI, 3306 MariaDB.
EXPOSE 80 443 8443 1025 8025 3306
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
