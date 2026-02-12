# Plan: Consolidate All Services into a Single Docker Container

## Context

Currently the setup uses 4 separate Docker containers (app, db, mailhog, phpmyadmin) orchestrated via docker-compose. The goal is to consolidate everything into 1 container for simplicity, using `supervisord` to manage all processes.

## Architecture Change

**Before:** 4 containers (app → PHP/Apache, db → MariaDB, mailhog → MailHog, phpmyadmin → phpMyAdmin)

**After:** 1 container running all 4 services managed by supervisord

| Service    | Runs On           | Port (internal) | Port (host)  |
|------------|-------------------|-----------------|--------------|
| Apache/PHP | supervisord       | 80, 443, 8443   | 8080, 8443   |
| MariaDB    | supervisord       | 3306            | 3400         |
| MailHog    | supervisord       | 1025, 8025      | 1025, 8025   |
| phpMyAdmin | Apache VirtualHost| 8081            | 8081         |

## Files to Modify

### 1. `Dockerfile` — Major rewrite
- Install `mariadb-server` and `supervisor` packages
- Download MailHog binary (architecture-aware for arm64/amd64)
- Install phpMyAdmin (download and extract to `/var/www/phpmyadmin/`)
- Copy `supervisord.conf` into the image
- Update `mhsendmail` sendmail_path to point to `localhost:1025` instead of `mailhog:1025`
- Create MariaDB data directory and set permissions
- Expose all ports: 80, 443, 1025, 3306, 8025, 8081, 8443

### 2. New file: `supervisord.conf`
- Manages 3 supervised processes: MariaDB, Apache, MailHog
- phpMyAdmin is served by Apache via a separate VirtualHost on port 8081 (not a separate process)
- All processes set to `autorestart=true`
- stdout/stderr logged for `docker logs` visibility

### 3. `entrypoint.sh` — Update
- Remove "wait for MariaDB" network loop (replace with local socket wait)
- Change `MYSQL_HOSTNAME` from `db` to `localhost`
- Initialize MariaDB data directory on first run (`mysql_install_db`)
- Start MariaDB temporarily for DB init, then stop it (supervisord will manage it)
- Create the `redcap` database if it doesn't exist
- Rest of init logic stays the same (install.sql, install_data.sql, CreateUsers.sql)
- At end: exec `supervisord` instead of `apachectl`

### 4. `docker-compose.yml` — Simplify to single service
- Remove `db`, `mailhog`, `phpmyadmin` services
- Remove `depends_on`, `healthcheck` sections
- Single `app` service exposing all ports (8080, 8443, 3400, 1025, 8025, 8081)
- Single volume for MariaDB data persistence
- Environment variables simplified (no MYSQL_HOSTNAME needed, always localhost)

### 5. `php.ini` — Update sendmail path
- Change `sendmail_path` from `mailhog:1025` to `localhost:1025`

### 6. New file: `phpmyadmin.conf` (Apache VirtualHost config)
- Serves phpMyAdmin on port 8081
- Points DocumentRoot to `/var/www/phpmyadmin/`
- Auto-login configured to connect to localhost MariaDB

### 7. `.env` — No changes needed (ports stay the same)

## Key Implementation Details

- **supervisord** manages MariaDB, Apache, and MailHog as child processes
- **phpMyAdmin** is served by Apache on a separate port (8081), not a separate process
- **MariaDB** connects via `localhost` / Unix socket instead of Docker network
- **MailHog** binary downloaded directly (no Go build needed, uses pre-built release)
- **mhsendmail** still used for PHP mail, but pointed to `localhost:1025`
- **Database persistence** via named Docker volume mounted at `/var/lib/mysql`

## Verification

1. `docker compose down -v` (clean start)
2. `docker compose up --build`
3. Verify REDCap: https://localhost:8443 — should show login page
4. Verify MailHog: http://localhost:8025 — should show MailHog UI
5. Verify phpMyAdmin: http://localhost:8081 — should show phpMyAdmin connected to redcap DB
6. Verify MariaDB: `docker exec -it redcap-app mysql -u root -proot redcap -e "SELECT 1"`
7. Login to REDCap as `test_admin` / `Testing123`
