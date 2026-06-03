#!/bin/bash
set -e

# ============================================================
# STEP 1: Generate database.php from environment variables
# ============================================================
cat > /var/www/html/database.php <<DBEOF
<?php

global \$log_all_errors;
\$log_all_errors = FALSE;

\$hostname   = '${MYSQL_HOSTNAME}';
\$db         = '${MYSQL_DATABASE}';
\$username   = '${MYSQL_USER}';
\$password   = '${MYSQL_PASSWORD}';

\$db_ssl_key     = '';
\$db_ssl_cert    = '';
\$db_ssl_ca      = '';
\$db_ssl_capath  = NULL;
\$db_ssl_cipher  = NULL;
\$db_ssl_verify_server_cert = false;

\$salt = '${REDCAP_SALT}';
DBEOF

echo "[entrypoint] database.php configured (host=${MYSQL_HOSTNAME}, db=${MYSQL_DATABASE})"

# ============================================================
# STEP 2: Ensure writable directories exist
# ============================================================
# redcap_file_repository is a bind-mount (see docker-compose.yml). The host
# directory's ownership (often a numeric uid like 1005:1003 that does not exist
# in the container) shadows the image's. Apache runs as www-data (uid 33) with
# no extra groups, so unless these are www-data-owned, exports fail to write
# the pidN subfolders. Re-assert ownership and setgid dir perms on every boot
# so this self-heals across rebuilds and bind-mount swaps.
mkdir -p /var/www/html/redcap_file_repository /var/www/html/temp /var/www/html/modules
chown -R www-data:www-data /var/www/html/redcap_file_repository /var/www/html/temp /var/www/html/modules
# 2775 (drwxrwsr-x) on all dirs: owner+group rwx, setgid so new pidN folders
# inherit the group; ug+rw on files. Tolerate odd FS that blocks chmod.
find /var/www/html/redcap_file_repository -type d -exec chmod 2775 {} \; 2>/dev/null || true
find /var/www/html/redcap_file_repository -type f -exec chmod ug+rw {} \; 2>/dev/null || true

# ============================================================
# STEP 2b: Fix permissions for external module file writes
# ============================================================
EM_FILES=(
  "Classes/Piping.php"
  "Classes/Hooks.php"
  "Classes/DataEntry.php"
  "Resources/js/DataQuality.js"
  "DataEntry/index.php"
)

REDCAP_CORE="/var/www/html/redcap_v${REDCAP_VERSION}"

if [ -d "$REDCAP_CORE" ]; then
  for f in "${EM_FILES[@]}"; do
    if [ -f "$REDCAP_CORE/$f" ]; then
      chown www-data:www-data "$REDCAP_CORE/$f"
      chmod 664 "$REDCAP_CORE/$f"
      echo "[entrypoint] Fixed permissions: $f"
    else
      echo "[entrypoint] WARNING: $f not found in $REDCAP_CORE"
    fi
  done
else
  echo "[entrypoint] WARNING: $REDCAP_CORE not found, skipping EM permission fix"
fi

# ============================================================
# STEP 3: Wait for MariaDB to be ready
# ============================================================
echo "[entrypoint] Waiting for MariaDB..."
MAX_RETRIES=30
RETRY_COUNT=0
until mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1" &>/dev/null; do
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
# STEP 4: Initialize REDCap database if this is the first run
# ============================================================
TABLE_COUNT=$(mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
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
    mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        "${MYSQL_DATABASE}" < "${INSTALL_SQL}"

    # Run install_data.sql (initial data)
    echo "[entrypoint] Running install_data.sql (initial data)..."
    mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        "${MYSQL_DATABASE}" < "${INSTALL_DATA_SQL}"

    # Set REDCap version, auth method, and base URL
    echo "[entrypoint] Configuring REDCap settings..."
    mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
        "${MYSQL_DATABASE}" -e "
        UPDATE redcap_config SET value = '${REDCAP_VERSION}' WHERE field_name = 'redcap_version';
        REPLACE INTO redcap_history_version (\`date\`, redcap_version) VALUES (CURDATE(), '${REDCAP_VERSION}');
        UPDATE redcap_config SET value = 'table' WHERE field_name = 'auth_meth_global';
        UPDATE redcap_config SET value = 'sha512' WHERE field_name = 'password_algo';
        UPDATE redcap_config SET value = 'admin@cctc.com' WHERE field_name = 'project_contact_email';
        UPDATE redcap_config SET value = 'CCTC Administrator' WHERE field_name = 'project_contact_name';
        UPDATE redcap_config SET value = '/var/www/html/redcap_file_repository/' WHERE field_name = 'edoc_path';
        UPDATE redcap_config SET value = 'https://localhost:${REDCAP_HTTPS_PORT:-8443}/' WHERE field_name = 'redcap_base_url';
        UPDATE redcap_config SET value = '/var/www/html/hook_functions.php' WHERE field_name = 'hook_functions_file';
    "

    # Create test users
    if [ -f /usr/local/share/redcap/CreateUsers.sql ]; then
        echo "[entrypoint] Creating test users..."
        mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" \
            "${MYSQL_DATABASE}" < /usr/local/share/redcap/CreateUsers.sql
    fi

    echo "[entrypoint] Database initialization complete."
else
    echo "[entrypoint] REDCap database already initialized. Skipping init."
fi

# ============================================================
# STEP 4b: Ensure per-project edoc subfolders exist on disk
# ============================================================
# REDCap stores each project's edocs under redcap_file_repository/<subfolder>/
# (subfolder name = redcap_projects.local_storage_subfolder, e.g. "pid2").
# If the row exists in the DB but the directory doesn't, exports fail silently
# (fopen returns false -> storeExportFile returns false -> "Export failed").
# Recreate any missing subfolders here so the dev env is resilient across
# rebuilds and bind-mount swaps.
mysql --skip-ssl -h "${MYSQL_HOSTNAME}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -N -e "
    SELECT local_storage_subfolder FROM ${MYSQL_DATABASE}.redcap_projects
    WHERE local_storage_subfolder IS NOT NULL AND local_storage_subfolder != '';" 2>/dev/null \
  | while read subdir; do
        [ -z "${subdir}" ] && continue
        mkdir -p "/var/www/html/redcap_file_repository/${subdir}"
        chown www-data:www-data "/var/www/html/redcap_file_repository/${subdir}"
        chmod 2775 "/var/www/html/redcap_file_repository/${subdir}"
    done

# ============================================================
# STEP 5: Configure internal SSL for REDCap self-check
# ============================================================
# REDCap's base URL uses the host-side HTTPS port (e.g. 8443), but inside the
# container Apache only listens on 443. This adds a second SSL VirtualHost on
# the host-mapped port so REDCap can reach itself at https://localhost:<port>/.
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
# STEP 6: Start Apache
# ============================================================
echo "[entrypoint] Starting Apache..."
exec apachectl -D FOREGROUND
