# CCTC REDCap Docker

A self-contained Docker setup that runs REDCap with MariaDB, MailHog, and phpMyAdmin. Place your REDCap source files, configure, and run `docker compose up --build`.

## Prerequisites

- Docker and Docker Compose ([Docker Desktop](https://www.docker.com/products/docker-desktop/))
- Valid REDCap license (to obtain source files)

---

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

Open a terminal and navigate into the `redcap_docker` folder:

```bash
cd redcap_docker
```

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set `REDCAP_VERSION` to match your version directory (e.g., `15.5.33`).

### 3. Build and Run

From within the `redcap_docker` folder in your terminal, run:

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

---

## Default Users

All test users have password: `Testing123`

| Username     | Role          |
|--------------|---------------|
| test_admin   | Super Admin   |
| test_user1   | Regular User  |
| test_user2   | Regular User  |
| test_user3   | Regular User  |
| test_user4   | Regular User  |
| test_monitor | Monitor       |
| test_dm      | Data Manager  |
| test_de1     | Data Entry 1  |
| test_de2     | Data Entry 2  |
| test_de3     | Data Entry 3  |
| test_depi    | Data Entry PI |

---

## Common Operations

All commands below must be run from within the `redcap_docker` folder in your terminal:

```bash
cd redcap_docker
```

### Stop services
```bash
docker compose down
```

### Start again (data persists)
```bash
docker compose up -d
```

### Rebuild after changes
```bash
docker compose up --build
```

### Change REDCap version
1. Place the new version directory in `redcap_source/`
2. Update `REDCAP_VERSION` in `redcap_docker/.env`
3. From within `redcap_docker`, rebuild:
   ```bash
   docker compose up --build
   ```

### Full database reset
```bash
docker compose down -v
docker compose up --build
```

### View logs
```bash
docker compose logs -f app
```

---

## Architecture

- **app**: PHP 8.2/Apache with REDCap source baked into the image
- **db**: MariaDB 10.5.29 with persistent volume
- **mailhog**: SMTP testing (captures all outgoing email)
- **phpmyadmin**: Database management UI

---

## Notes

- All `docker compose` commands must be run from inside the `redcap_docker/` directory
- SSL uses self-signed certificates (browser warnings are expected)
- MailHog captures all email sent by REDCap — no email leaves the system
- The database is automatically initialized on first startup
- Data persists in Docker volumes across restarts
- Rebuilding (`--build`) does **not** reset the database — use `docker compose down -v` to reset
