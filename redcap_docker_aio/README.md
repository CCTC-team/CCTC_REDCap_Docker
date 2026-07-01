# All-in-one REDCap image (`redcap_docker_aio/`)

A **single self-contained image** that runs REDCap + MariaDB + MailHog in **one
container**, supervised by `supervisord`. One `docker compose up` (or one
`docker run`) stands up a fully working REDCap instance — no sidecar containers.

This is the REDCap half of the two-image test stack; the Cypress suite runs
against it from [`../redcap_cypress/cypress_runner/`](../redcap_cypress/cypress_runner/README.md).

> Contrast with [`../redcap_docker/`](../redcap_docker/), which runs REDCap,
> MariaDB and MailHog as **three separate containers**. The all-in-one trades
> Docker's per-service isolation for a single shippable image.

---

## Quick start

```bash
cd CCTC_REDCap_Docker/redcap_docker_aio
cp .env.example .env          # adjust REDCAP_VERSION / ports if needed
docker compose up -d --build
```

| Service | URL |
|---------|-----|
| REDCap (HTTPS) | https://localhost:8443 |
| REDCap (HTTP)  | http://localhost:8080 |
| MailHog UI     | http://localhost:8025 |
| MariaDB        | `127.0.0.1:3400` |

Built image: **`cctc/redcap-${REDCAP_VERSION}:${REDCAP_IMAGE_TAG}`** (e.g.
`cctc/redcap-15.5.36:v1.0.0`). Container name: **`CCTC_REDCap_Docker`**.

Log in with `test_admin` / `Testing123` (see the full user list in the repo
[README](../README.md#default-users)).

### Bare `docker run` (no compose)

```bash
docker run -d --name CCTC_REDCap_Docker \
  -p 8080:80 -p 8443:8443 -p 8025:8025 -p 1025:1025 -p 3400:3306 \
  -v cctc_mariadb_data:/var/lib/mysql \
  cctc/redcap-15.5.36:v1.0.0
```

---

## What's inside

| Component | Notes |
|-----------|-------|
| REDCap (PHP 8.2 / Apache) | source **baked into the image** at build time |
| MariaDB | data in the **`cctc_mariadb_data`** volume (`/var/lib/mysql`) |
| MailHog | built from source (native arm64); catches all REDCap email |
| supervisord | the in-container init that runs all three |

[`entrypoint.sh`](entrypoint.sh) bootstraps the DB on first boot (schema, data,
test users), then hands off to `supervisord`.

---

## Things to know

- **REDCap source is writable but ephemeral.** It lives in the container's
  writable layer, so external modules can inject code and core files can be
  edited at runtime — but those edits **reset to pristine on container
  recreation** (`docker compose down` / `--force-recreate`). They survive
  `stop`/`start`. This is intentional for reproducible test runs.
- **The database persists** in `cctc_mariadb_data` across recreate. To wipe it
  for a clean slate: `docker compose down -v`.
- **Recreate is safe.** `docker compose up -d` on an existing volume re-uses the
  DB; the entrypoint authenticates root with or without a password (fresh vs.
  persisted datadir) so it won't crash on restart.
- **MariaDB durability is relaxed** (`innodb_flush_log_at_trx_commit=0`,
  `sync_binlog=0`, `innodb_doublewrite=OFF`) so the per-test DB reseed is fast.
  Safe here because the test DB is disposable — only crash-durability is traded.
- **SSL** uses a self-signed cert (browser warnings expected).
- **Email** never leaves the system — `mhsendmail` routes all PHP mail to the
  in-container MailHog.

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

## Common operations

```bash
docker compose logs -f                 # follow boot + service logs
docker compose down                    # stop (DB volume kept)
docker compose up -d                   # start again (DB persists)
docker compose down -v                 # stop + wipe the database
docker compose up -d --build           # rebuild after Dockerfile/entrypoint changes
```
