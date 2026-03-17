# CCTC REDCap Docker

A self-contained Docker setup that runs REDCap with MariaDB and MailHog. Place your REDCap source files, configure, and run `docker compose up --build -d`.

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

---

## Architecture

- **app**: PHP 8.2/Apache with REDCap source baked into the image
- **db**: MariaDB 10.11 with persistent volume
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

---

## Who are we

The Cambridge Cancer Trials Centre (CCTC) is a collaboration between Cambridge University Hospitals NHS Foundation Trust, the University of Cambridge, and Cancer Research UK. Founded in 2007, CCTC designs and conducts clinical trials and studies to improve outcomes for patients with cancer or those at risk of developing it. In 2011, CCTC began hosting the Cambridge Clinical Trials Unit - Cancer Theme (CCTU-CT).

CCTC has two divisions: Cancer Theme, which coordinates trial delivery, and Clinical Operations.