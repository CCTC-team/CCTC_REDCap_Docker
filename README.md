# CCTC REDCap Docker

A self-contained Docker setup that runs REDCap with MariaDB and MailHog. Place your REDCap source files, configure, and run `docker compose up --build -d`.

---

## Who are we

The Cambridge Cancer Trials Centre (CCTC) is a collaboration between Cambridge University Hospitals NHS Foundation Trust, the University of Cambridge, and Cancer Research UK. Founded in 2007, CCTC designs and conducts clinical trials and studies to improve outcomes for patients with cancer or those at risk of developing it. In 2011, CCTC began hosting the Cambridge Clinical Trials Unit - Cancer Theme (CCTU-CT).

CCTC has two divisions: Cancer Theme, which coordinates trial delivery, and Clinical Operations.

## Prerequisites

- Docker and Docker Compose ([Docker](https://www.docker.com))
- Valid REDCap licence (to obtain source files)

---

## Quick Start

### 1. Clone the repo

```bash
git clone git@github.com:CCTC-team/CCTC_REDCap_Docker.git
```

### 2. Place REDCap source files

Copy your REDCap installation files (contents inside the redcap folder) into the `redcap_source/` directory. The structure should look like:

```
redcap_source/
├── redcap_v15.5.36/       # Version directory (name must match your version)
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

### 3. Configure

Open a terminal and navigate into the `redcap_docker` folder:

```bash
cd CCTC_REDCap_Docker/redcap_docker
```

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set `REDCAP_VERSION` to match your version directory (e.g., `15.5.36`).

### 4. Build and Run

From within the `redcap_docker` folder in your terminal, run:

```bash
docker compose up --build -d
```

On first run, the database is automatically initialised with REDCap's schema, data, and test users.

### 5. Access

| Service    | URL                        |
|------------|----------------------------|
| REDCap     | https://localhost:8443     |
| REDCap     | http://localhost:8080      |
| MailHog    | http://localhost:8025      |

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
docker compose up --build -d
```

### Change REDCap version
1. Place the new version directory in `redcap_source/`
2. Update `REDCAP_VERSION` in `redcap_docker/.env`
3. From within `redcap_docker`, rebuild:
   ```bash
   docker compose up --build -d
   ```

### Full database reset
```bash
docker compose down -v
docker compose up --build -d
```

### View logs
```bash
docker compose logs -f app
```

### Run against a prebuilt image (CI / external modules)
Instead of building REDCap from source, you can consume a versioned image published to
GHCR (`ghcr.io/CCTC-team/redcap_cypress/redcap-env:<REDCAP_VERSION>`), so every consumer
tests the byte-identical REDCap. Two compose overrides enable this (layer them on top of
`docker-compose.yml`):

- **`docker-compose.prebuilt.yml`** — replaces the `app` build with `image:` so `up` pulls
  the prebuilt image instead of rebuilding from source:
  ```bash
  docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml pull app
  docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml up -d
  ```
- **`docker-compose.em.yml`** — additionally bind-mounts an external module's code into the
  prebuilt image at runtime (no rebuild), at `/var/www/html/modules/<name>_<version>/`:
  ```bash
  EM_HOST_PATH=/abs/path/to/em EM_DIR=embellish_fields_v1.0.3 \
    docker compose -f docker-compose.yml -f docker-compose.prebuilt.yml -f docker-compose.em.yml up -d
  ```

The prebuilt image is built and pushed by the `build-docker-image.yml` workflow in the
`redcap_cypress` repo. The standard `up --build` flow above is unchanged for local dev.

---

## Data Integrity Checks

The `redcap_docker/Audit_Analysis_Reports/` directory is a bind mount into the MariaDB container (`/var/lib/mysql/Audit_Analysis_Reports`). When running scripts from the [REDCap_Data_Integrity_Checks](https://github.com/CCTC-team/REDCap_Data_Integrity_Checks) repository, the results will be written here and available on your host machine.

This directory is git-ignored and will not be committed.

---

## Architecture

- **app**: PHP 8.2/Apache with REDCap source baked into the image
- **db**: MariaDB 10.11 with persistent volume and `Audit_Analysis_Reports` bind mount for data integrity check results
- **mailhog**: SMTP testing (captures all outgoing email)

---

## Notes

- All `docker compose` commands must be run from inside the `redcap_docker/` directory
- SSL uses self-signed certificates (browser warnings are expected)
- MailHog captures all email sent by REDCap — no email leaves the system
- The database is automatically initialised on first startup
- Data persists in Docker volumes across restarts
- Rebuilding (`--build`) does **not** reset the database — use `docker compose down -v` to reset

## Upgrading REDCap
Download upgrade.zip for your target REDCap version from the community page. Unzip it and copy the contents of the 'redcap' folder (the redcap_vxx.x.xx folder) into redcap_source/

Either

open the browser, go to 'Control Center' and press the upgrade button or
navigate to https://localhost:8443/upgrade.php in your browser
Note: if the upgrade.php doesn't work, try invoking upgrade.php inside the version folder (redcap_vxx.x.xx).

https://localhost:8443/redcap_vxx.x.xx/upgrade.php
Follow the instructions in the browser to upgrade REDCap

Ensure the configuration checks in the ‘Control Center’ pass

After upgrade, replace any outdated files in the redcap root directory (e.g. redcap_connect.php). If any exist, download the zip file from the ‘Configuration Check’ link in ‘Control Center’, unzip it and place it in the 'redcap_source' folder.