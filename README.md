# REDCap Standalone Docker

A single-container Docker setup that runs REDCap with MariaDB, MailHog, and phpMyAdmin — all managed by supervisord. Just place your REDCap source files, configure, and run `docker compose up --build`.

## Prerequisites

- Docker and Docker Compose
- Valid REDCap license (to obtain source files)

## Quick Start

### 1. Place REDCap source files

Copy your REDCap installation files into the `redcap_source/` directory. The structure should look like:

```
redcap_source/
├── redcap_v15.5.33/       # Version directory (name must match your version)
├── install.php
├── upgrade.php
├── redcap_connect.php
├── index.php
├── cron.php
├── api/
├── bin/
├── hooks/
├── Languages/
├── modules/
└── ...
```

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env` and set `REDCAP_VERSION` to match your version directory (e.g., `15.5.33`).

### 3. Build and Run

```bash
docker compose up --build
```

On first run, the database is automatically initialized with REDCap's schema, data, and test users.

### 4. Access

| Service    | URL                        |
|------------|----------------------------|
| REDCap     | https://localhost:8443     |
| REDCap     | http://localhost:8080      |
| MailHog    | http://localhost:8025      |
| phpMyAdmin | http://localhost:8081      |

Login with `test_admin` / `Testing123`.

## Default Users

All test users have password: `Testing123`

| Username     | Role         |
|-------------|--------------|
| test_admin  | Super Admin  |
| test_user1  | Regular User |
| test_user2  | Regular User |
| test_user3  | Regular User |
| test_user4  | Regular User |
| test_monitor| Monitor      |
| test_dm     | Data Manager |
| test_de1    | Data Entry 1 |
| test_de2    | Data Entry 2 |
| test_de3    | Data Entry 3 |
| test_depi   | Data Entry PI|

## Common Operations

### Stop services
```bash
docker compose down
```

### Start again (data persists)
```bash
docker compose up
```

### Change REDCap version
1. Place the new version directory in `redcap_source/`
2. Update `REDCAP_VERSION` in `.env`
3. Rebuild: `docker compose up --build`

### Full database reset
```bash
docker compose down -v
docker compose up --build
```

### View logs
```bash
docker compose logs -f
```

### Access container shell
```bash
docker exec -it redcap-app bash
```

### Access database directly
```bash
docker exec -it redcap-app mysql -u root -proot redcap
```

## Architecture

Everything runs in a single Docker container (`redcap-app`) using **supervisord** to manage three processes:

- **Apache/PHP 8.2** — Serves REDCap (ports 80/443/8443) and phpMyAdmin (port 8081)
- **MariaDB** — Database server (port 3306, exposed as 3400 on host)
- **MailHog** — SMTP testing (captures all outgoing email, web UI on 8025)

On first startup, the entrypoint script automatically:
1. Initializes the MariaDB data directory
2. Creates the database and runs REDCap install SQL scripts
3. Configures REDCap settings (base URL, auth method, etc.)
4. Creates all test users
5. Hands off to supervisord for ongoing process management

## Notes

- SSL uses self-signed certificates (browser warnings are expected)
- MailHog captures all email sent by REDCap (no email leaves the system)
- The database is automatically initialized on first startup
- Data persists in Docker volumes across restarts
- Rebuilding the image (`--build`) does NOT reset the database; use `docker compose down -v` to reset
- phpMyAdmin is auto-configured to connect with root credentials
