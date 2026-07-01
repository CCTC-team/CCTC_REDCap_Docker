#!/bin/bash
set -e

DATADIR=/var/lib/mysql
SOCK=/run/mysqld/mysqld.sock
DB="${MYSQL_DATABASE:-redcap}"
DB_PASS="${MYSQL_PASSWORD:-root}"
SALT="${REDCAP_SALT:-12345678}"
HTTPS_PORT="${REDCAP_HTTPS_PORT:-8443}"

mkdir -p /run/mysqld /var/log/supervisor
chown mysql:mysql /run/mysqld

# ============================================================
# STEP 1: Initialize the MariaDB data dir on first boot
# ============================================================
if [ ! -d "${DATADIR}/mysql" ]; then
    echo "[entrypoint] Initializing MariaDB data directory..."
    mariadb-install-db --user=mysql --datadir="${DATADIR}" \
        --auth-root-authentication-method=normal --skip-test-db >/dev/null
fi
chown -R mysql:mysql "${DATADIR}"

# ============================================================
# STEP 2: Start a temporary MariaDB for bootstrapping
# ============================================================
echo "[entrypoint] Starting temporary MariaDB for bootstrap..."
mariadbd --user=mysql --datadir="${DATADIR}" --socket="${SOCK}" \
    --skip-networking --pid-file=/run/mysqld/bootstrap.pid \
    --innodb-flush-log-at-trx-commit=0 --sync-binlog=0 --innodb-doublewrite=0 &
BOOT_PID=$!

echo "[entrypoint] Waiting for MariaDB socket..."
for _ in $(seq 1 30); do
    mysqladmin --socket="${SOCK}" ping &>/dev/null && break
    sleep 1
done
if ! mysqladmin --socket="${SOCK}" ping &>/dev/null; then
    echo "[entrypoint] ERROR: bootstrap MariaDB did not come up."
    exit 1
fi
echo "[entrypoint] MariaDB is ready (bootstrap)."

# ============================================================
# STEP 3: Ensure database + root credentials (TCP access)
# ============================================================
# REDCap connects over TCP to 127.0.0.1 as root. Set the password and grant a
# 127.0.0.1 root user. Idempotent: safe to re-run on every boot.
#
# root@localhost has an EMPTY password on a freshly-initialized datadir but the
# real password on a persisted volume (cctc_mariadb_data). Pick whichever auth
# connects so recreate-with-existing-volume doesn't fail with "Access denied".
if mysql --socket="${SOCK}" -uroot -e "SELECT 1" &>/dev/null; then
    ROOT_AUTH=(-uroot)
elif mysql --socket="${SOCK}" -uroot -p"${DB_PASS}" -e "SELECT 1" &>/dev/null; then
    ROOT_AUTH=(-uroot -p"${DB_PASS}")
else
    echo "[entrypoint] ERROR: cannot authenticate to bootstrap MariaDB as root."
    exit 1
fi
mysql --socket="${SOCK}" "${ROOT_AUTH[@]}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB}\`;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

# ============================================================
# STEP 4: Generate database.php (REDCap -> 127.0.0.1)
# ============================================================
cat > /var/www/html/database.php <<DBEOF
<?php

global \$log_all_errors;
\$log_all_errors = FALSE;

\$hostname   = '127.0.0.1';
\$db         = '${DB}';
\$username   = 'root';
\$password   = '${DB_PASS}';

\$db_ssl_key     = '';
\$db_ssl_cert    = '';
\$db_ssl_ca      = '';
\$db_ssl_capath  = NULL;
\$db_ssl_cipher  = NULL;
\$db_ssl_verify_server_cert = false;

\$salt = '${SALT}';
DBEOF
echo "[entrypoint] database.php configured (host=127.0.0.1, db=${DB})"

# ============================================================
# STEP 5: First-run REDCap schema + data + users
# ============================================================
# Root now has a password (set in STEP 3), so socket logins must supply it.
MYSQL_BOOT=(mysql --socket="${SOCK}" -uroot -p"${DB_PASS}")
TABLE_COUNT=$("${MYSQL_BOOT[@]}" -N -e \
    "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB}' AND table_name='redcap_config';" 2>/dev/null)

if [ "${TABLE_COUNT}" = "0" ]; then
    echo "[entrypoint] First run detected -- initializing REDCap database..."
    SQL_DIR="/var/www/html/redcap_v${REDCAP_VERSION}/Resources/sql"
    INSTALL_SQL="${SQL_DIR}/install.sql"
    INSTALL_DATA_SQL="${SQL_DIR}/install_data.sql"

    if [ ! -f "${INSTALL_SQL}" ] || [ ! -f "${INSTALL_DATA_SQL}" ]; then
        echo "[entrypoint] ERROR: install SQL not found under ${SQL_DIR}."
        echo "[entrypoint] Check REDCAP_VERSION=${REDCAP_VERSION} matches a redcap_source/ dir."
        exit 1
    fi

    echo "[entrypoint] Running install.sql (schema)..."
    "${MYSQL_BOOT[@]}" "${DB}" < "${INSTALL_SQL}"
    echo "[entrypoint] Running install_data.sql (initial data)..."
    "${MYSQL_BOOT[@]}" "${DB}" < "${INSTALL_DATA_SQL}"

    echo "[entrypoint] Configuring REDCap settings..."
    "${MYSQL_BOOT[@]}" "${DB}" -e "
        UPDATE redcap_config SET value = '${REDCAP_VERSION}' WHERE field_name = 'redcap_version';
        REPLACE INTO redcap_history_version (\`date\`, redcap_version) VALUES (CURDATE(), '${REDCAP_VERSION}');
        UPDATE redcap_config SET value = 'table' WHERE field_name = 'auth_meth_global';
        UPDATE redcap_config SET value = 'sha512' WHERE field_name = 'password_algo';
        UPDATE redcap_config SET value = 'admin@cctc.com' WHERE field_name = 'project_contact_email';
        UPDATE redcap_config SET value = 'CCTC Administrator' WHERE field_name = 'project_contact_name';
        UPDATE redcap_config SET value = '/var/www/html/redcap_file_repository/' WHERE field_name = 'edoc_path';
        UPDATE redcap_config SET value = 'https://localhost:${HTTPS_PORT}/' WHERE field_name = 'redcap_base_url';
        UPDATE redcap_config SET value = '/var/www/html/hook_functions.php' WHERE field_name = 'hook_functions_file';
    "

    if [ -f /usr/local/share/redcap/CreateUsers.sql ]; then
        echo "[entrypoint] Creating test users..."
        "${MYSQL_BOOT[@]}" "${DB}" < /usr/local/share/redcap/CreateUsers.sql
    fi
    echo "[entrypoint] Database initialization complete."
else
    echo "[entrypoint] REDCap database already initialized. Skipping init."
fi

# ============================================================
# STEP 6: Writable runtime dirs + edoc subfolders
# ============================================================
mkdir -p /var/www/html/redcap_file_repository /var/www/html/temp /var/www/html/modules
chown -R www-data:www-data /var/www/html/redcap_file_repository /var/www/html/temp /var/www/html/modules
find /var/www/html/redcap_file_repository -type d -exec chmod 2775 {} \; 2>/dev/null || true

"${MYSQL_BOOT[@]}" -N -e "
    SELECT local_storage_subfolder FROM ${DB}.redcap_projects
    WHERE local_storage_subfolder IS NOT NULL AND local_storage_subfolder != '';" 2>/dev/null \
  | while read subdir; do
        [ -z "${subdir}" ] && continue
        mkdir -p "/var/www/html/redcap_file_repository/${subdir}"
        chown www-data:www-data "/var/www/html/redcap_file_repository/${subdir}"
        chmod 2775 "/var/www/html/redcap_file_repository/${subdir}"
    done

# ============================================================
# STEP 7: Stop the bootstrap MariaDB (supervisord starts the real one)
# ============================================================
echo "[entrypoint] Stopping bootstrap MariaDB..."
mysqladmin --socket="${SOCK}" -uroot -p"${DB_PASS}" shutdown 2>/dev/null || kill "${BOOT_PID}" 2>/dev/null || true
wait "${BOOT_PID}" 2>/dev/null || true

# ============================================================
# STEP 8: Internal SSL vhost + trust self-signed cert
# ============================================================
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

if [ -f /etc/ssl/certs/mycert.crt ]; then
    cp /etc/ssl/certs/mycert.crt /usr/local/share/ca-certificates/mycert.crt
    update-ca-certificates 2>/dev/null || true
    echo "[entrypoint] Self-signed certificate added to CA trust store."
fi

# ============================================================
# STEP 9: Hand off to supervisord (MariaDB + Mailhog + Apache)
# ============================================================
echo "[entrypoint] Starting supervisord (mariadb + mailhog + apache)..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
