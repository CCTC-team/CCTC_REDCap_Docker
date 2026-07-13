# CCTC REDCap Docker

[![Build and Push REDCap All-in-One Image](https://github.com/CCTC-team/CCTC_REDCap_Docker/actions/workflows/build-redcap-aio.yml/badge.svg?branch=redcap_val)](https://github.com/CCTC-team/CCTC_REDCap_Docker/actions/workflows/build-redcap-aio.yml)

A self-contained Docker setup that runs REDCap with MariaDB and MailHog in **one container** (supervised by `supervisord`). Place your REDCap source files, configure, and run `docker compose up --build -d`.

---

## The image

This repo builds a single **all-in-one** REDCap image from [`redcap_docker_aio/`](redcap_docker_aio/) — REDCap + MariaDB + MailHog in one container via `supervisord` — and publishes it to GHCR (`ghcr.io/cctc-team/cctc_redcap_docker/redcap-aio`). It is documented throughout this README.

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

Open a terminal and navigate into the `redcap_docker_aio` folder:

```bash
cd CCTC_REDCap_Docker/redcap_docker_aio
```

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and set `REDCAP_VERSION` to match your version directory (e.g., `15.5.36`). See [Configuration](#configuration-env) for the full list of variables.

### 4. Build and Run

From within the `redcap_docker_aio` folder in your terminal, run:

```bash
docker compose up --build -d
```

On first run, the database is automatically initialised with REDCap's schema, data, and test users.

<details>
<summary>Bare <code>docker run</code> (no compose)</summary>

Uses the image built locally by the `docker compose up --build` step above (`cctc/redcap-<version>:<tag>`) — build it first; this does not pull from a registry.

```bash
docker run -d --name CCTC_REDCap_Docker \
  -p 8080:80 -p 8443:8443 -p 8025:8025 -p 1025:1025 -p 3400:3306 \
  -v cctc_mariadb_data:/var/lib/mysql \
  cctc/redcap-15.5.36:v1.0.0
```
</details>

### 5. Access

| Service    | URL                        |
|------------|----------------------------|
| REDCap     | https://localhost:8443     |
| REDCap     | http://localhost:8080      |
| MailHog    | http://localhost:8025      |
| MariaDB    | `localhost:3400` (`127.0.0.1:3400` for the `mysql` CLI) |

The built image is **`cctc/redcap-${REDCAP_VERSION}:${REDCAP_IMAGE_TAG}`** (e.g. `cctc/redcap-15.5.36:v1.0.0`); the container is named **`CCTC_REDCap_Docker`**.

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

## Configuration (`.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `REDCAP_VERSION` | `15.5.36` | must match a `redcap_v*` dir in `../redcap_source/` |
| `REDCAP_IMAGE_TAG` | `v1.0.0` | image tag → `cctc/redcap-<version>:<tag>` |
| `MYSQL_ROOT_PASSWORD` | `root` | MariaDB root password |
| `MYSQL_DATABASE` | `redcap` | database name |
| `REDCAP_SALT` | `12345678` | hash salt — do **not** change after first install |
| `REDCAP_HTTP_PORT` / `REDCAP_HTTPS_PORT` | `8080` / `8443` | host web ports |
| `MYSQL_PORT` | `3400` | host MariaDB port |
| `MAILHOG_SMTP_PORT` / `MAILHOG_UI_PORT` | `1025` / `8025` | host MailHog ports |

---

## What's inside

A single container (`CCTC_REDCap_Docker`) runs all three services under `supervisord`:

| Component | Notes |
|-----------|-------|
| REDCap (PHP 8.2 / Apache) | source **baked into the image** at build time |
| MariaDB | data in the **`cctc_mariadb_data`** volume (`/var/lib/mysql`), plus an `Audit_Analysis_Reports` bind mount for data integrity check results |
| MailHog | built from source (native arm64); catches all REDCap email |
| supervisord | the in-container init that runs all three |

[`redcap_docker_aio/entrypoint.sh`](redcap_docker_aio/entrypoint.sh) bootstraps the DB on first boot (schema, data, test users), then hands off to `supervisord`.

---

## Things to know

- **REDCap source is writable but ephemeral.** It lives in the container's writable layer, so external modules can inject code and core files can be edited at runtime — but those edits **reset to pristine on container recreation** (`docker compose down` / `--force-recreate`). They survive `stop`/`start`. This is intentional for reproducible test runs.
- **The database persists** in `cctc_mariadb_data` across recreate. Rebuilding (`--build`) does **not** reset it. To wipe it for a clean slate: `docker compose down -v`.
- **Recreate is safe.** `docker compose up -d` on an existing volume re-uses the DB; the entrypoint authenticates root with or without a password (fresh vs. persisted datadir) so it won't crash on restart.
- **MariaDB durability is relaxed** (`innodb_flush_log_at_trx_commit=0`, `sync_binlog=0`, `innodb_doublewrite=OFF`) so the per-test DB reseed is fast. Safe here because the test DB is disposable — only crash-durability is traded.
- **SSL** uses a self-signed cert (browser warnings expected).
- **Email** never leaves the system — `mhsendmail` routes all PHP mail to the in-container MailHog.

---

## Common Operations

All commands below must be run from within the `redcap_docker_aio` folder in your terminal:

```bash
cd redcap_docker_aio
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
2. Update `REDCAP_VERSION` in `redcap_docker_aio/.env`
3. From within `redcap_docker_aio`, rebuild:
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
docker compose logs -f
```

### Run against a prebuilt image (CI / external modules)
Instead of building REDCap from source, you can pull the versioned all-in-one image published
to GHCR (`ghcr.io/cctc-team/cctc_redcap_docker/redcap-aio:<REDCAP_VERSION>`), so every consumer
tests the byte-identical REDCap. Set `REDCAP_IMAGE` in `.env`, then pull instead of build:

```bash
# in redcap_docker_aio/.env
REDCAP_IMAGE=ghcr.io/cctc-team/cctc_redcap_docker/redcap-aio:15.5.36

docker compose pull && docker compose up -d
```

To develop an external module against the running image without a rebuild, bind-mount its code
into the container at `/var/www/html/modules/<name>_<version>/` via a `volumes:` entry in
`docker-compose.yml` (see the module-mount note in that file).

---

## Continuous Integration

[![Build and Push REDCap All-in-One Image](https://github.com/CCTC-team/CCTC_REDCap_Docker/actions/workflows/build-redcap-aio.yml/badge.svg?branch=redcap_val)](https://github.com/CCTC-team/CCTC_REDCap_Docker/actions/workflows/build-redcap-aio.yml)

The [.github/workflows/build-redcap-aio.yml](.github/workflows/build-redcap-aio.yml) workflow — **Build and Push REDCap All-in-One Image** — builds the single-container image from [`redcap_docker_aio/`](redcap_docker_aio/) and pushes it to GHCR as `ghcr.io/cctc-team/cctc_redcap_docker/redcap-aio`. This is the REDCap half of the two-image test stack that `redcap_cypress`'s [cypress-tests-aio.yml](https://github.com/CCTC-team/redcap_cypress/actions/workflows/cypress-tests-aio.yml) runs against.

**Triggers**
- **Push** to `redcap_val` touching `redcap_docker_aio/**` or the workflow file itself
- **Manual** via the Actions tab (`workflow_dispatch`), with an optional extra `tag` input

**What it does**
1. Reads `REDCAP_VERSION` from `redcap_docker_aio/.env.example` (the version source of truth).
2. Clones the matching version branch of the private [`CCTC-team/redcap_source`](https://github.com/CCTC-team/redcap_source) into `redcap_source/` (using `CCTC_TEAM_PAT`).
3. Builds `redcap_docker_aio/Dockerfile` for **`linux/amd64`** and pushes it tagged with the REDCap version, `latest` (on the default branch), and the short commit SHA.
4. Prunes old image versions, keeping the latest 2.

**Required secrets**
- `CCTC_TEAM_PAT` — clones `redcap_source` and prunes old GHCR image versions.
- `GITHUB_TOKEN` — GHCR login for the push (built-in).

> **`docker-compose.yml` vs `Dockerfile` — what CI actually uses.** `docker-compose.yml` is for **local dev only**. The **Dockerfile** is what CI cares about: it produces the image. The Cypress suite then consumes that prebuilt image via `docker run`, bypassing both the Dockerfile build and Compose. So a change to `docker-compose.yml` affects only local dev; changes that must reach CI belong in the **Dockerfile** (or the image tag the workflows pull).

---

## Data Integrity Checks

The `redcap_docker_aio/Audit_Analysis_Reports/` directory is a bind mount into the all-in-one container (`CCTC_REDCap_Docker`) at `/var/lib/mysql/Audit_Analysis_Reports`. When running scripts from the [REDCap_Data_Integrity_Checks](https://github.com/CCTC-team/REDCap_Data_Integrity_Checks) repository, the results will be written here and available on your host machine.

This directory is git-ignored and will not be committed.

---

## Upgrading REDCap

> **Why the extra copy step?** `redcap_source/` is **COPYed into the image at build time** (see [redcap_docker_aio/Dockerfile](redcap_docker_aio/Dockerfile) — `COPY redcap_source/ /var/www/html/`), it is **not** bind-mounted. So placing a new `redcap_vXX.X.XX` folder into `redcap_source/` on your host does **not** make it appear in the already-running container — you must either copy it into the running container or rebuild the image.

### 1. Download the new version

Download `upgrade.zip` for your target REDCap version from the [REDCap Community](https://redcap.vanderbilt.edu/community/) page. Unzip it and copy the version directory (`redcap_vXX.X.XX`) into `redcap_source/`, so the structure looks like:

```
redcap_source/
└── redcap_vXX.X.XX/
```

### 2. Get the new version into the container

Choose one of the two options below.

#### Option A — copy into the running container (quick, keeps your data)

Copy the new version folder into the running container, then run the upgrade manually:

```bash
# from CCTC_REDCap_Docker/  (container name: CCTC_REDCap_Docker)
docker cp ../redcap_source/redcap_vXX.X.XX CCTC_REDCap_Docker:/var/www/html/redcap_vXX.X.XX
docker exec CCTC_REDCap_Docker chown -R www-data:www-data /var/www/html/redcap_vXX.X.XX
```

**Run the upgrade** — either open the browser, go to **Control Center** and press the **upgrade** button, or navigate to:

```
https://localhost:8443/upgrade.php
```

Note: if `upgrade.php` at the root doesn't work, invoke it inside the version folder:

```
https://localhost:8443/redcap_vXX.X.XX/upgrade.php
```

Follow the instructions in the browser to complete the upgrade.

**Verify** — ensure the configuration checks in **Control Center** pass. After upgrade, replace any outdated files in the REDCap root directory (e.g. `redcap_connect.php`). If the **Configuration Check** flags any, download the zip from its link in **Control Center**, unzip it, and place the files in `redcap_source/` — then re-copy them into the container (`docker cp`).

> Option A does not survive an image rebuild. To make the upgrade permanent, also do Option B (bump `REDCAP_VERSION` and rebuild) afterwards.

#### Option B — rebuild so the new source is baked into the image (permanent; required for CI / prebuilt image)

```bash
# from redcap_docker_aio/
# bump REDCAP_VERSION in .env to XX.X.XX first
docker compose up --build -d
```

No manual upgrade step is needed — the rebuilt image serves the new version directly.