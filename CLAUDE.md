# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

**CCTC_REDCap_Docker** is a self-contained Docker environment for running REDCap with MariaDB and MailHog. It is designed for both standalone use and as part of the CCTC REDCap Cypress automated testing pipeline.

See [README.md](README.md) for setup instructions, common commands, default users, and access URLs.

## Project Structure

```
CCTC_REDCap_Docker/
├── redcap_docker/
│   ├── docker-compose.yml    # Defines 3 services: app, db, mailhog
│   ├── Dockerfile            # PHP 8.2/Apache image with REDCap baked in
│   ├── entrypoint.sh         # Auto-initializes DB on first run, starts Apache
│   ├── .env.example          # Template for environment variables
│   ├── database.php          # Template for REDCap DB connection config
│   ├── CreateUsers.sql       # Seeds 11 test users into the database
│   ├── php.ini               # Custom PHP configuration
│   └── volumes/              # Docker volume data
├── redcap_source/            # REDCap source files (not committed)
├── CONTRIBUTING.md           # Contribution guidelines
└── creating-an-automated-testing-environment.md
```

## Docker Services

- **app (redcap-app)**: PHP 8.2.28/Apache on ports 8080 (HTTP) and 8443 (HTTPS). REDCap source is COPYed into the image at build time, not mounted. Includes ImageMagick for PDF support.
- **db (redcap-db)**: MariaDB 10.11 on port 3400. Uses named volume `mariadb_data` for persistence.
- **mailhog (redcap-mailhog)**: Email testing on ports 1025 (SMTP) and 8025 (Web UI). Captures all outgoing email.

## Key Implementation Details

- **Database auto-init**: `entrypoint.sh` checks for `redcap_config` table. If absent, runs `install.sql` + `install_data.sql`, seeds test users, and configures REDCap settings automatically.
- **SSL**: Self-signed certificates generated at build time. An internal SSL VirtualHost is created on the host-mapped HTTPS port so REDCap's self-check works.
- **Email**: PHP uses `mhsendmail` to route all mail to MailHog SMTP. Nothing leaves the system.
- **REDCap source is baked in**: The `redcap_source/` directory is COPYed into the image at build time. Changes require `docker compose up --build`.
- **PHP extensions**: mysqli, GD, zip, imagick (for PDF support in REDCap 13+).
- **ImageMagick policy**: Modified to allow PDF read/write operations.

## Environment Variables (.env)

| Variable             | Default    | Description                                      |
|----------------------|------------|--------------------------------------------------|
| REDCAP_VERSION       | 15.5.36    | Must match directory name under `redcap_source/`  |
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
- `REDCAP_SALT` must never change after the first database initialization.
