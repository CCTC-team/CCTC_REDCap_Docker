# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**CCTC_REDCap_Docker** is a self-contained Docker environment for running REDCap with MariaDB and MailHog. It is designed for both standalone use and as part of the CCTC REDCap Cypress automated testing pipeline.

See [README.md](README.md) for setup instructions, common commands, default users, and access URLs.

## Stacks in this repo

- **`redcap_docker_aio/`** — the all-in-one image and **sole REDCap stack**: REDCap + MariaDB + MailHog in ONE container via supervisord. Built as `cctc/redcap-<version>:<tag>`, container `CCTC_REDCap_Docker`, DB volume `cctc_mariadb_data`. Documented in the top-level [README.md](README.md).
- **`redcap_cypress/cypress_runner/`** — a runner image with `redcap_rsvc` + `rctf` baked in; runs the feature suite headless against the `redcap_docker_aio/` container (`docker exec` for DB/files, host network for HTTP, private deps cloned via BuildKit SSH). Lives inside the `redcap_cypress/` suite so its Docker build context is that suite. See [redcap_cypress/cypress_runner/README.md](redcap_cypress/cypress_runner/README.md).

## Project Structure

```
CCTC_REDCap_Docker/
├── redcap_docker_aio/          # the all-in-one image (sole REDCap stack)
│   ├── Dockerfile              # single image: REDCap + MariaDB + MailHog, baked in
│   ├── docker-compose.yml      # stands up ONE container (service `redcap`)
│   ├── entrypoint.sh           # bootstraps DB on first boot, then hands off to supervisord
│   ├── supervisord.conf        # in-container init running all three services
│   ├── conf/redcap.ini         # PHP overrides (mail routed to local MailHog)
│   ├── CreateUsers.sql         # seeds 11 test users into the database
│   ├── .env.example            # template env (REDCAP_VERSION is the version source of truth)
│   └── Audit_Analysis_Reports/ # data integrity check results (git-ignored, bind-mounted)
├── redcap_cypress/             # Cypress test suite + cypress_runner/ CI image
├── redcap_source/              # REDCap source files (not committed; COPYed into image)
├── README.md                   # full setup, config, operations
└── Setup_Overview.md           # higher-level tie-together guide
```

## Container & Services

A single container (`CCTC_REDCap_Docker`) runs all three services under `supervisord`:

- **REDCap**: PHP 8.2/Apache on ports 8080 (HTTP) and 8443 (HTTPS). Source is COPYed into the image at build time, not mounted. Includes ImageMagick for PDF support.
- **MariaDB**: on host port 3400 (container 3306). Persists in the named volume `cctc_mariadb_data` (`/var/lib/mysql`). Bind-mounts `redcap_docker_aio/Audit_Analysis_Reports` to `/var/lib/mysql/Audit_Analysis_Reports` for [REDCap_Data_Integrity_Checks](https://github.com/CCTC-team/REDCap_Data_Integrity_Checks) output.
- **MailHog**: ports 1025 (SMTP) and 8025 (Web UI). Built from source; captures all outgoing email.

## Key Implementation Details

- **Database auto-init**: `entrypoint.sh` checks for `redcap_config` table. If absent, runs `install.sql` + `install_data.sql`, seeds test users, and configures REDCap settings automatically. It then hands off to `supervisord`, which runs REDCap (Apache), MariaDB, and MailHog.
- **SSL**: Self-signed certificates generated at build time. An internal SSL VirtualHost is created on the host-mapped HTTPS port so REDCap's self-check works.
- **Email**: PHP uses `mhsendmail` to route all mail to MailHog SMTP. Nothing leaves the system.
- **REDCap source is baked in**: The `redcap_source/` directory is COPYed into the image at build time. Changes require `docker compose up --build`.
- **PHP extensions**: mysqli, GD, zip, imagick (for PDF support in REDCap 13+).
- **ImageMagick policy**: Modified to allow PDF read/write operations.

## Environment Variables (.env)

| Variable             | Default    | Description                                      |
|----------------------|------------|--------------------------------------------------|
| REDCAP_VERSION       | 15.5.36    | Must match directory name under `redcap_source/`  |
| REDCAP_IMAGE_TAG     | v1.0.0     | Image tag → `cctc/redcap-<version>:<tag>`        |
| MYSQL_ROOT_PASSWORD  | root       | MariaDB root password                            |
| MYSQL_DATABASE       | redcap     | Database name                                    |
| REDCAP_SALT          | 12345678   | REDCap hash salt (do NOT change after first run) |
| REDCAP_HTTP_PORT     | 8080       | Host port for HTTP                               |
| REDCAP_HTTPS_PORT    | 8443       | Host port for HTTPS                              |
| MYSQL_PORT           | 3400       | Host port for MariaDB                            |
| MAILHOG_SMTP_PORT    | 1025       | Host port for MailHog SMTP                       |
| MAILHOG_UI_PORT      | 8025       | Host port for MailHog web UI                     |

## Editing Guidelines

- When modifying `Dockerfile` or `entrypoint.sh`, always rebuild with `docker compose up --build`.
- The `redcap_source/` directory is COPYed at build time, not mounted. Changes require a rebuild.
- Do not commit `.env` (contains credentials) or `redcap_source/` (licensed software).
- `REDCAP_SALT` must never change after the first database initialisation.
