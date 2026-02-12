#!/bin/bash
set -e

MYSQL_DATABASE="${MYSQL_DATABASE:-redcap}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"

# ============================================================
# STEP 1: Generate database.php from environment variables
# ============================================================
cat > /var/www/html/database.php <<DBEOF
<?php

global \$log_all_errors;
\$log_all_errors = FALSE;

\$hostname   = 'localhost';
\$db         = '${MYSQL_DATABASE}';
\$username   = 'root';
\$password   = '${MYSQL_ROOT_PASSWORD}';

\$db_ssl_key     = '';
\$db_ssl_cert    = '';
\$db_ssl_ca      = '';
\$db_ssl_capath  = NULL;
\$db_ssl_cipher  = NULL;
\$db_ssl_verify_server_cert = false;

\$salt = '${REDCAP_SALT}';
DBEOF

echo "[entrypoint] database.php configured (host=localhost, db=${MYSQL_DATABASE})"

# ============================================================
# STEP 2: Ensure writable directories exist
# ============================================================
mkdir -p /var/www/html/edocs /var/www/html/temp /var/www/html/modules
chown -R www-data:www-data /var/www/html/edocs /var/www/html/temp /var/www/html/modules

# ============================================================
# STEP 3: Initialize MariaDB data directory if needed
# ============================================================
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[entrypoint] First run detected -- initializing MariaDB data directory..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    echo "[entrypoint] MariaDB data directory initialized."
fi

# ============================================================
# STEP 4: Start MariaDB temporarily for initialization
# ============================================================
echo "[entrypoint] Starting MariaDB temporarily for initialization..."
mariadbd --user=mysql \
    --max_allowed_packet=128M \
    --optimizer_switch=rowid_filter=OFF &
MARIADB_PID=$!

# Wait for MariaDB to be ready
MAX_RETRIES=30
RETRY_COUNT=0
until mysql -u root -e "SELECT 1" &>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "[entrypoint] ERROR: MariaDB not ready after ${MAX_RETRIES} attempts."
        exit 1
    fi
    echo "[entrypoint] MariaDB not ready (attempt ${RETRY_COUNT}/${MAX_RETRIES}). Retrying in 2s..."
    sleep 2
done
echo "[entrypoint] MariaDB is ready."

# ============================================================
# STEP 5: Set root password and create database
# ============================================================
# Set the root password (MariaDB starts with no password after mysql_install_db)
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" 2>/dev/null || true

# Create database if it doesn't exist
mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};" 2>/dev/null

# ============================================================
# STEP 6: Initialize REDCap database if this is the first run
# ============================================================
TABLE_COUNT=$(mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
    -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE}' AND table_name='redcap_config';" 2>/dev/null)

if [ "${TABLE_COUNT}" = "0" ]; then
    echo "[entrypoint] First run detected -- initializing REDCap database..."

    # Locate SQL install files
    SQL_DIR="/var/www/html/redcap_v${REDCAP_VERSION}/Resources/sql"
    INSTALL_SQL="${SQL_DIR}/install.sql"
    INSTALL_DATA_SQL="${SQL_DIR}/install_data.sql"

    if [ ! -f "${INSTALL_SQL}" ]; then
        echo "[entrypoint] ERROR: Cannot find ${INSTALL_SQL}"
        echo "[entrypoint] Check that REDCAP_VERSION=${REDCAP_VERSION} matches a directory in redcap_source/"
        exit 1
    fi

    if [ ! -f "${INSTALL_DATA_SQL}" ]; then
        echo "[entrypoint] ERROR: Cannot find ${INSTALL_DATA_SQL}"
        exit 1
    fi

    # Run install.sql (schema creation)
    echo "[entrypoint] Running install.sql (schema)..."
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
        "${MYSQL_DATABASE}" < "${INSTALL_SQL}"

    # Run install_data.sql (initial data)
    echo "[entrypoint] Running install_data.sql (initial data)..."
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
        "${MYSQL_DATABASE}" < "${INSTALL_DATA_SQL}"

    # Set REDCap version, auth method, and base URL
    echo "[entrypoint] Configuring REDCap settings..."
    mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
        "${MYSQL_DATABASE}" -e "
        UPDATE redcap_config SET value = '${REDCAP_VERSION}' WHERE field_name = 'redcap_version';
        REPLACE INTO redcap_history_version (\`date\`, redcap_version) VALUES (CURDATE(), '${REDCAP_VERSION}');
        UPDATE redcap_config SET value = 'table' WHERE field_name = 'auth_meth_global';
        UPDATE redcap_config SET value = 'sha512' WHERE field_name = 'password_algo';
        UPDATE redcap_config SET value = 'admin@cctc.com' WHERE field_name = 'project_contact_email';
        UPDATE redcap_config SET value = 'CCTC Administrator' WHERE field_name = 'project_contact_name';
        UPDATE redcap_config SET value = '/var/www/html/redcap_file_repository/' WHERE field_name = 'edoc_path';
        UPDATE redcap_config SET value = 'https://localhost:${REDCAP_HTTPS_PORT:-8443}/' WHERE field_name = 'redcap_base_url';
    "

    # Create test users
    if [ -f /usr/local/share/redcap/CreateUsers.sql ]; then
        echo "[entrypoint] Creating test users..."
        mysql -u root -p"${MYSQL_ROOT_PASSWORD}" \
            "${MYSQL_DATABASE}" < /usr/local/share/redcap/CreateUsers.sql
    fi

    echo "[entrypoint] Database initialization complete."
else
    echo "[entrypoint] REDCap database already initialized. Skipping init."
fi

# ============================================================
# STEP 7: Stop temporary MariaDB (supervisord will manage it)
# ============================================================
echo "[entrypoint] Stopping temporary MariaDB..."
kill "$MARIADB_PID"
wait "$MARIADB_PID" 2>/dev/null || true
echo "[entrypoint] Temporary MariaDB stopped."

# ============================================================
# STEP 8: Configure internal SSL for REDCap self-check
# ============================================================
HTTPS_PORT="${REDCAP_HTTPS_PORT:-8443}"
if [ "${HTTPS_PORT}" != "443" ]; then
    echo "[entrypoint] Configuring internal SSL on port ${HTTPS_PORT}..."
    cat > /etc/apache2/sites-enabled/redcap-internal-ssl.conf <<SSLEOF
Listen ${HTTPS_PORT}
<VirtualHost *:${HTTPS_PORT}>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/mycert.crt
    SSLCertificateKeyFile /etc/ssl/private/mycert.key
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
SSLEOF
fi

# Trust the self-signed certificate so PHP/curl can verify it
if [ -f /etc/ssl/certs/mycert.crt ]; then
    cp /etc/ssl/certs/mycert.crt /usr/local/share/ca-certificates/mycert.crt
    update-ca-certificates 2>/dev/null
    echo "[entrypoint] Self-signed certificate added to CA trust store."
fi

# ============================================================
# STEP 9: Start all services via supervisord
# ============================================================
echo "[entrypoint] Starting all services via supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
