# CCTC REDCap Docker & Cypress Testing — Setup Overview

This document walks you through setting up the **CCTC REDCap Docker** environment and running automated **Cypress** tests against it. Detailed instructions live in README files within the repo — this guide ties them together and gives you the full picture.

---

## What This Project Is

This repository provides a self-contained, Dockerised REDCap instance paired with an automated Cypress test suite. It has four main components:

| Component | Location | Purpose |
|---|---|---|
| **[CCTC_REDCap_Docker](https://github.com/CCTC-team/CCTC_REDCap_Docker)** | `CCTC_REDCap_Docker/` | Docker environment running REDCap, MariaDB, and MailHog |
| **[redcap_cypress](https://github.com/CCTC-team/redcap_cypress)** | `redcap_cypress/` | Cypress + Gherkin BDD test framework |
| **[redcap_rsvc](https://github.com/CCTC-team/redcap_rsvc)** | `redcap_rsvc/` | 755+ RSVC validation feature tests (Tiers A–D) |
| **[rctf](https://github.com/CCTC-team/rctf)** | `node_modules/rctf/` | Step definitions for the Gherkin feature tests in redcap_rsvc |

### How They Fit Together

```
CCTC_REDCap_Docker (Docker containers)
  └── Runs REDCap + MariaDB + MailHog
        ▲
        │  tests run against
        │
redcap_cypress (Cypress framework)
  └── Uses redcap_rsvc feature files + rctf step definitions
```

Cypress connects to the Dockerised REDCap instance, resets the database to a clean state before each test, and executes Gherkin `.feature` files that validate REDCap functionality.

---

## Prerequisites

- **Docker** — installed and running
- **A valid REDCap licence** — you must supply the REDCap source code yourself
- **Node.js and npm** — for running Cypress
- **Cypress ^15.10.0** — installed as part of `npm install`

---

## Part 1: Set Up the REDCap Docker Environment

> Full details: [`CCTC_REDCap_Docker/README.md`](README.md)

### Steps

1. **Clone the repository** (if you haven't already).

2. **Place your REDCap source files** into `CCTC_REDCap_Docker/redcap_source/`. The folder should contain a version directory, e.g.:
   ```
   CCTC_REDCap_Docker/redcap_source/redcap_v15.5.36/
   ```

3. **Configure the `.env` file** in `CCTC_REDCap_Docker/redcap_docker/`. Copy from `.env.example` if needed, then set `REDCAP_VERSION` to match your source folder (e.g., `15.5.36`).

4. **Build and start the containers**:
   ```bash
   cd CCTC_REDCap_Docker/redcap_docker
   docker compose up --build -d
   ```

5. **Access REDCap**:
   - HTTPS: https://localhost:8443 (self-signed cert — accept the browser warning)
   - HTTP: http://localhost:8080
   - MailHog UI: http://localhost:8025

### Services at a Glance

| Service | Technology | Ports |
|---|---|---|
| REDCap App | PHP 8.2 / Apache | 8080 (HTTP), 8443 (HTTPS) |
| Database | MariaDB 10.11 | 3400 |
| Mail Capture | MailHog | 1025 (SMTP), 8025 (Web UI) |

### Default Test Users

The database is automatically seeded with 11 test users (password for all: `Testing123`):

| Username | Role |
|---|---|
| `test_admin` | Super Admin |
| `test_user1` – `test_user4` | Regular Users |
| `test_monitor` | Monitor |
| `test_dm` | Data Manager |
| `test_de1` – `test_de3` | Data Entry |
| `test_depi` | Data Entry PI |

### Common Docker Operations

```bash
# Stop containers
docker compose down

# Restart without rebuilding
docker compose up -d

# Full reset (wipes database)
docker compose down -v && docker compose up --build -d

# View logs
docker compose logs -f app
```

For more Docker operations and troubleshooting, see [`CCTC_REDCap_Docker/README.md`](README.md).

---

## Part 2: Set Up the Cypress Test Framework

> Full details: [`redcap_cypress/README.md`](https://github.com/CCTC-team/redcap_cypress/blob/redcap_val//README.md)
>
> Folder structure reference: [`redcap_cypress/FOLDER_STRUCTURE.md`](https://github.com/CCTC-team/redcap_cypress/blob/redcap_val/FOLDER_STRUCTURE.md)

### Steps

1. **Navigate to the Cypress directory**:
   ```bash
   cd CCTC_REDCap_Docker/redcap_cypress
   ```

2. **Copy the example config files** (if they exist) and adjust settings in:
   - `cypress.config.js` — update `baseUrl` (default `https://localhost:8443`) and `mailHogUrl` (default `http://localhost:8025`) to match your Docker setup
   - `cypress.env.json` — test users, REDCap version, MySQL connection, timezone

3. **Install dependencies**:
   ```bash
   npm install
   ```

4. **Install the RSVC feature tests**:
   ```bash
   npm run redcap_rsvc:install
   ```
   This pulls the RSVC test suite into `redcap_rsvc/`.

### Important Warning

> **Never use production database credentials in `cypress.env.json`.** The test suite resets the database to a clean state before each feature test. This will destroy all data in the target database.

---

## Part 3: Run the Tests

### Interactive Mode (Cypress UI)

```bash
npx cypress open
```

This opens the Cypress Test Runner where you can browse and run individual feature files.

### Headless Mode (CLI)

```bash
npx cypress run
```

Runs all tests in the terminal without opening a browser window.

---

## Test Organisation (RSVC Tiers)

> Full details: [`redcap_rsvc/README.md`](https://github.com/CCTC-team/redcap_rsvc/blob/redcap_val/README.md)

Feature tests are organised into four tiers under `redcap_rsvc/Feature Tests/`:

| Tier | Scope | Maintained By |
|---|---|---|
| **A — Core Admin-Level** | Admin-level core functionality | RSVC |
| **B — Core Project-Level** | Project-level core functionality | RSVC |
| **C — Non-Core (RSVC)** | Non-core features (e-Consent, randomization, etc.) | RSVC / RVP |
| **D — Site-Managed** | Site-specific and non-core features outside RSVC scope | CCTC / Site |

Custom CCTC feature files (not from RSVC) are located in the D folder.

---

## Step Definitions

Core step definitions live in the **[rctf](https://github.com/CCTC-team/rctf/tree/redcap_val)** package (`node_modules/rctf/`). Additional CCTC-specific step definitions are in `redcap_cypress/cypress/support/step_definitions/`:

| File | Purpose |
|---|---|
| `noncore.js` | CCTC additional step definitions |
| `external_module.js` | CCTC External module step definitions |

---

## Quick-Start Checklist

- [ ] Docker installed and running
- [ ] REDCap source placed in `CCTC_REDCap_Docker/redcap_source/`
- [ ] `.env` configured with correct `REDCAP_VERSION`
- [ ] `docker compose up --build -d` completes successfully
- [ ] REDCap accessible at https://localhost:8443
- [ ] Can log in as `test_admin` / `Testing123`
- [ ] Node.js and npm installed
- [ ] `npm install` completed in `redcap_cypress/`
- [ ] `npm run redcap_rsvc:install` completed
- [ ] `cypress.config.js` configured (`baseUrl` and `mailHogUrl` match your setup)
- [ ] `cypress.env.json` configured
- [ ] `npx cypress open` launches successfully

---

## Adapting This for Your Institution

It is complex but possible to create your own environment to run all automated tests and fully reproduce this validation process at your institution. We are unable to assist in setting up such an environment for other institutions, but provide this documentation as a starting point.

REDCap's automated tests should be executed against a REDCap test server instance mirroring your site's production REDCap instance. [CCTC REDCap Cypress Developer Toolkit](https://github.com/CCTC-team/redcap_cypress.git) may be a useful starting point. Rerunning tests using a similar configuration will not provide feedback specific to your institution, or any results meaningfully different than CCTC's validation process.

The following steps may be a useful checklist when configuring your institution's automation environment:

1. **Checkout REDCap and related source code** intended for deployment (includes REDCap source + could include hooks, plugins, EMs, etc.)
2. Checkout **redcap_cypress** repository
3. Generate **cypress.config.js** from **cypress.config.js.example** and update **baseUrl** and **mailHogUrl** to point to your REDCap and MailHog instances. Generate **cypress.env.json** from **cypress.env.json.example** and set **redcap_version** and **MySQL** environment variables as needed for your environment.
4. Set desired **redcap_rsvc** version in **package.json** (e.g. `"redcap_rsvc": "git://github.com/CCTC-team/redcap_rsvc.git#v15.5.36"`)
5. Install Cypress and RCTF dependencies: `npm install`
6. Install REDCap RSVC feature tests (as defined in **package.json**): `npm run redcap_rsvc:install`
7. Start test instance of REDCap (if not already running). Command is specific to test instance implementation.
8. Run Cypress tests (e.g. `CYPRESS_prettyEnabled=true npx cypress run --record --key $RECORD_KEY --browser chrome`)

How the specific commands above look will vary widely based on your environment.

---

## Further Reading

| Document | Location |
|---|---|
| Docker environment setup | [`CCTC_REDCap_Docker/README.md`](https://github.com/CCTC-team/CCTC_REDCap_Docker/blob/redcap_val/README.md) |
| Cypress testing framework | [`redcap_cypress/README.md`](https://github.com/CCTC-team/redcap_cypress/blob/redcap_val/README.md) |
| Folder structure reference | [`redcap_cypress/FOLDER_STRUCTURE.md`](https://github.com/CCTC-team/redcap_cypress/blob/redcap_val/FOLDER_STRUCTURE.md) |
| RSVC test suite details | [`redcap_rsvc/README.md`](https://github.com/CCTC-team/redcap_rsvc/blob/redcap_val/README.md) |