# Two-Image REDCap + Cypress Stack Implementation Plan

> **ARCHITECTURE PIVOT (Image A).** After Phase 1 was built and verified as a
> 3-container stack (`minimal/`), the user chose a **single all-in-one image**
> instead: REDCap + MariaDB + Mailhog in ONE image, supervised by supervisord,
> run as one container. This lives in **`redcap_docker_aio/`** and is built/verified as
> `cctc/redcap-15.5.36:v1.0.0` (container `CCTC_REDCap_Docker`, DB volume
> `cctc_mariadb_data`). See *Phase 1-AIO* below. The `minimal/` 3-container stack
> is retained but superseded. **Impact on Image B (Phase 2-3):** the Cypress
> runner reaches the DB/files via `docker exec` against the single container
> `CCTC_REDCap_Docker` (not `redcap-db`); set `CYPRESS_MYSQL_CONTAINER=CCTC_REDCap_Docker`.

## Phase 1-AIO: All-in-one REDCap image (`redcap_docker_aio/`) — DONE & VERIFIED

- [x] `redcap_docker_aio/Dockerfile` — php:8.2-apache + mariadb-server + supervisor; mhsendmail
  and **MailHog built from source** (native arm64). MailHog has no go.mod so
  module-mode pulls latest transitive deps requiring newer Go → build uses the
  **latest stable Go** (`go.dev/VERSION`, resolved to go1.26.4) to satisfy them.
  Source baked + `chown -R www-data`.
- [x] `redcap_docker_aio/supervisord.conf` — runs mariadbd + mailhog + apache2 (foreground).
- [x] `redcap_docker_aio/entrypoint.sh` — first-boot: init datadir → temp mariadbd → set root
  password + create DB → generate `database.php` (127.0.0.1) → install REDCap
  schema/data/users → stop temp mariadbd → internal SSL vhost + cert trust →
  `exec supervisord`. **Fix:** post-password socket logins use `-uroot -p`.
- [x] `redcap_docker_aio/docker-compose.yml` — one `redcap` service, container
  `CCTC_REDCap_Docker`, image `cctc/redcap-${REDCAP_VERSION}:${REDCAP_IMAGE_TAG}`,
  volume `cctc_mariadb_data` (explicit `name:`), ports 8080/8443/8025/1025/3400.
- [x] `redcap_docker_aio/conf/redcap.ini`, `redcap_docker_aio/.env.example`, `redcap_docker_aio/CreateUsers.sql`.
- [x] **Verified:** image builds (2.21 GB); single container boots; supervisord
  runs all three; `https://localhost:8443` → REDCap 15.5.36 (HTTP 200); 12 users;
  Mailhog UI/API up; PHP mail → Mailhog confirmed (message caught).

---

## Context

Goal: two self-contained Docker images that replace the current sprawl of
compose overrides and the bind-mount-based local runner.

- **Image A — REDCap environment.** `redcap_source` (a specific REDCap version)
  baked into the image. `docker compose up` in its folder stands up a working
  REDCap instance plus MariaDB and Mailhog, fully wired. Source lives in the
  container's writable layer: external modules can inject code and core files can
  be edited at runtime, but edits are **ephemeral** — they reset to the pristine
  baked source on container recreation (`down` / `--force-recreate`). This is
  desirable for reproducible test runs.

- **Image B — Cypress test runner.** `redcap_rsvc` (the feature-test specs +
  fixtures) and `rctf` (the REDCap Cypress Test Framework / step definitions)
  **baked in** via `npm ci` at build time — no host source mount, no runtime
  `npm ci`. Run on demand against an already-running Image A; it executes the
  suite and writes a report, then exits. Re-runnable without restarting REDCap.

Two decisions locked with the user:

1. **Two stacks, not one combined run.** Image A is a long-running stack brought
   up once. Image B is fired on demand (its own compose / `docker run`),
   repeatedly, without rebooting REDCap.
2. **Docker-socket access, not a network refactor.** Image B reaches REDCap's
   **database and filesystem** through `docker exec redcap-db mysql …` and
   `docker exec` / `docker cp` against `redcap-app` (this is how the existing
   framework works — see `docker_bin/mysql` and the `cypress.config.js` tasks).
   So Image B mounts `/var/run/docker.sock` and ships the docker CLI. No changes
   to `rctf` or the wrappers.

Sharding is intentionally **out of scope for v1** (single runner runs the whole
suite, or a `--spec` subset). `docker_bin/cypress-runner/run-ci.sh` already
contains shard logic to graft on later if needed.

This is infrastructure/config work (Dockerfiles, compose, shell), not
application logic, so there are no unit tests to drive TDD. Verification is a
real end-to-end run (an explicit TDD exception: integration wiring only
meaningful once real).

---

## Key References

- `CCTC_REDCap_Docker/redcap_docker/Dockerfile` + `entrypoint.sh` —
  the proven REDCap build/boot to distil Image A from (PHP exts, ImageMagick PDF
  policy, MariaDB-wait + first-run SQL install, internal SSL vhost). Image A's
  container names **must stay** `redcap-app` / `redcap-db` / `redcap-mailhog` —
  Image B reaches them by those exact names.
- `CCTC_REDCap_Docker/redcap_cypress/docker_bin/cypress-runner/Dockerfile` —
  ~90% of Image B already: `cypress/included` + native Chromium + python3 +
  `libxml2-utils` (xmllint) + static docker CLI. v1 adapts this to **bake** the
  tree instead of bind-mounting it.
- `CCTC_REDCap_Docker/redcap_cypress/docker_bin/cypress-runner/run.sh` — the
  proven runtime wiring (`--network host`, socket mount, node_modules volume).
  Image B's compose reproduces this in declarative form.
- `CCTC_REDCap_Docker/redcap_cypress/docker_bin/mysql` — the `docker exec -i
  $CYPRESS_MYSQL_CONTAINER mysql` wrapper. Confirms the socket dependency and the
  `redcap-db` container-name contract.
- `CCTC_REDCap_Docker/redcap_cypress/cypress.env.json` — `mysql.docker_container:
  "redcap-db"`, `redcap_version: 15.5.36`, REDCap container paths
  (`/var/www/html/...`). Defines the A↔B contract.
- `CCTC_REDCap_Docker/redcap_cypress/package.json` — scripts
  `redcap_rsvc:move_files`, `rctf:get_step_features` that prepare the working
  tree after install. NB: **do not** use `redcap_rsvc:install` / `clean` — they
  delete `package-lock.json` and cause the esbuild "Expected id 3 but got id 2"
  crash; use `npm ci` then the file-move steps directly.

---

## Key Design Decisions

1. **Image A: bake source, ephemeral writable layer.** `COPY redcap_source/
   /var/www/html/`; entrypoint `chown -R www-data` the REDCap tree so any core
   file or `modules/` injection is writable at runtime. Recreation discards the
   layer → pristine source each run. Rejected: host source bind-mount (defeats
   baking, host/UID permission fights) and seed-once volume (persists edits —
   not wanted). *(This is the `minimal/` work already started.)*

2. **Image A keeps the `redcap-{app,db,mailhog}` container names.** Image B's DB
   and file access is `docker exec redcap-db` / `docker exec redcap-app`. The
   names are a hard contract, so the minimal compose pins `container_name:`
   exactly as the legacy stack did. (This also means only one Image-A instance
   runs at a time — fine for the two-stack, no-shard v1.)

3. **Image B: bake `redcap_rsvc` + `rctf` via `npm ci` at build.** The image is
   self-contained; no host tree, no runtime install. Build runs `npm ci` then the
   `redcap_rsvc:move_files` + `rctf:get_step_features` prep so specs/fixtures/step
   features are in place. Rejected: the current bind-mount + runtime `npm ci`
   (not self-contained; slow first run). Rejected: `redcap_rsvc:install`/`clean`
   (deletes `package-lock.json` → esbuild crash, per the known CI failure).

4. **Image B reaches A via Docker socket + host networking.** Mirrors the proven
   `run.sh`: `network_mode: host` so `baseUrl https://localhost:8443` matches
   REDCap's stored `redcap_base_url` (no redirect mismatch), and a mounted
   `/var/run/docker.sock` so the `docker exec`/`docker cp` tasks work unchanged.
   Rejected: bridge network + service-name baseUrl (REDCap's stored base_url is
   `localhost:8443`; cross-host redirects break) and the TCP/shared-volume
   refactor (more work, diverges from rctf/CI expectations).

5. **Results escape via a bind mount, not baked.** Image B bind-mounts
   `./results` (or `cypress/results`) to the host so the mochawesome report and
   videos survive the container exit. Specs are baked (read-only); only output
   is mounted.

6. **No sharding in v1.** One runner, whole suite or `--spec` subset via a
   `SPEC`/passthrough env. Keeps the first cut simple; `run-ci.sh` is the
   reference when shards are wanted.

---

## Phase 1: Image A — REDCap environment (`minimal/`)

- [x] **1a. NEW:** `CCTC_REDCap_Docker/minimal/Dockerfile` — `php:8.2.30-apache`,
  `ARG REDCAP_VERSION`, PHP exts (mysqli/gd/zip/imagick), ImageMagick PDF policy,
  mhsendmail, self-signed cert, `cp php.ini-production` + conf.d override,
  `COPY redcap_source/ /var/www/html/` with `redcap_connect.php` guard, entrypoint
  + `CreateUsers.sql`. *Status: written.*

- [x] **1b. NEW:** `CCTC_REDCap_Docker/minimal/CreateUsers.sql` — copied verbatim
  from `redcap_docker/CreateUsers.sql`. *Status: copied.*

- [x] **1c. NEW:** `CCTC_REDCap_Docker/minimal/conf/redcap.ini` — REDCap PHP
  overrides (`memory_limit=512M`, upload/post 100M, `max_input_vars=100000`,
  `date.timezone`, `session.cookie_secure=On`, opcache) + mailhog
  `sendmail_path = "/usr/bin/mhsendmail --smtp-addr=mailhog:1025"`. *Status: written.*

- [x] **1d. NEW:** `CCTC_REDCap_Docker/minimal/entrypoint.sh` — trimmed from
  `redcap_docker/entrypoint.sh`: generate `database.php`; wait for MariaDB;
  first-run `install.sql` + `install_data.sql` + config rows (version/auth/
  `redcap_base_url`=`https://localhost:${REDCAP_HTTPS_PORT}/`/edoc_path) +
  `CreateUsers.sql`; recreate missing per-project edoc subfolders; internal SSL
  vhost on the HTTPS port + trust cert; `exec apachectl -D FOREGROUND`. Dropped
  pcov/coverage and the per-file EM chmod list. *Status: written; `bash -n` clean.*
  - **Deviation from plan:** the tree-wide `chown -R www-data:www-data
    /var/www/html` (Decision 1) was moved to **build time** in the Dockerfile
    (line 74) rather than the entrypoint, so it costs nothing on every boot since
    the source is baked (not bind-mounted). Entrypoint keeps a light chown of the
    runtime dirs (file_repository/temp/modules) for self-healing.
  - Review: subagent diff vs `redcap_docker/entrypoint.sh` — **passed clean**: no
    boot-critical step dropped (cert trust, edoc recreation, base-url port all
    present), no correctness bugs; the two intended omissions are properly
    compensated.

- [x] **1e. NEW:** `CCTC_REDCap_Docker/minimal/docker-compose.yml` — `app`
  (build context `..`, dockerfile `minimal/Dockerfile`, `args REDCAP_VERSION`,
  `container_name: redcap-app`, ports `8080:80`/`8443:443`, `depends_on db`
  healthy), `db` (`mariadb:10.11`, `container_name: redcap-db`, named volume,
  healthcheck, tuning flags), `mailhog` (`container_name: redcap-mailhog`, UI
  `8025`/SMTP `1025`). Container names pinned per Decision 2. No source bind-mount.
  - **Deviation from plan:** the `app` service sets
    `image: cctc/redcap-${REDCAP_VERSION}:${REDCAP_IMAGE_TAG:-v1.0.0}` so the built
    image is named meaningfully (e.g. `cctc/redcap-15.5.36:v1.0.0`) instead of the
    Compose default `minimal-app:latest`.

- [x] **1f. NEW:** `CCTC_REDCap_Docker/minimal/.env.example` —
  `REDCAP_VERSION=15.5.36`, `REDCAP_IMAGE_TAG=v1.0.0`, DB creds, salt, port mappings.

**Phase 1 verified end-to-end:** image `redcap-15.5.36:v1.0.0` builds; stack boots
(db healthy → app inits DB → Apache up); `https://localhost:8443/` serves REDCap
15.5.36 (HTTP 200); 12 test users seeded; base_url correct; recreate-under-new-name
re-uses the persisted DB volume (skips re-init).

---

## Phase 2-3: Cypress runner (`cypress_runner/`) — DONE & VERIFIED

Built as `cctc/redcap-cypress:15.10.0`; runs the suite on demand against the
all-in-one `CCTC_REDCap_Docker` container. **A real feature test passed
end-to-end** (`A.1.1.0100 Run Configuration Check` → 1 passing).

- [x] `cypress_runner/Dockerfile` — `cypress/included:15.10.0` + chromium + python3
  + xmllint + git/openssh-client + static docker CLI. Bakes the suite tree;
  `npm ci` over **BuildKit SSH** (`--mount=type=ssh`) to clone the private
  `rctf`/`redcap_rsvc` GitHub deps; `redcap_rsvc:move_files` prep. sed-patches the
  hardcoded `redcap-app` container name to honor `CYPRESS_REDCAP_CONTAINER`.
  - **Deviation:** dropped `rctf:get_step_features` — it's only for rctf's own
    self-tests (needs `node_modules/rctf/tests/step_features`, absent in the pkg),
    NOT for the redcap_rsvc Feature Tests (the actual specs).
- [x] `cypress_runner/Dockerfile.dockerignore` — context = repo root, whitelists
  `redcap_cypress/` + `cypress_runner/` only; excludes host node_modules, the
  `redcap_rsvc/` working copy, videos/results/test_db.
- [x] `cypress_runner/entrypoint.sh` — verifies `docker exec` to the REDCap
  container; **`docker cp`s `redcap_v<ver>/Resources/sql` out of the running
  REDCap container** (rctf `populateStructureAndData` reads install/demo SQL from
  the local FS — image stays decoupled, no redcap_source bake) and sets
  `CYPRESS_redcap_source_path`; `mkdir -p test_db`; waits for REDCap; `cypress run`;
  report.
- [x] `cypress_runner/docker-compose.yml` + `.env.example` — `network_mode: host`,
  Docker socket mount (`${HOME}/.docker/run/docker.sock`), `build.ssh: [default]`,
  results bind-mount. Run: `docker compose build --ssh default` then
  `docker compose run --rm cypress [--spec ...]`.
- [x] **Verified:** build succeeds (672 pkgs via SSH; 2.69 GB); 308 feature tests
  + fixtures baked; runner reaches REDCap over host net + DB via `docker exec`;
  `A.1.1.0100` passes.

---

## Phase 2-3 (original spec): Image B — SUPERSEDED by the DONE block above

These were the pre-implementation descriptions; the **Phase 2-3 (DONE & VERIFIED)**
section above is the as-built record. Key differences from the original spec:

- [x] **2a/3b — Dockerfile + ignore:** built; context = **repo root** with
  `cypress_runner/Dockerfile.dockerignore` (BuildKit prefers it over the root
  ignore that excludes `redcap_cypress/`). `npm ci` clones the private deps over
  **BuildKit SSH** (`--mount=type=ssh`). Prep = `redcap_rsvc:move_files` only;
  **`rctf:get_step_features` dropped** (rctf self-tests, not the feature specs).
- [x] **2b — entrypoint:** built; additionally **`docker cp`s `Resources/sql`**
  out of the running REDCap container (rctf reads install/demo SQL from local FS)
  and `mkdir -p test_db`. `CYPRESS_MYSQL_CONTAINER` + `CYPRESS_REDCAP_CONTAINER`
  set to **`CCTC_REDCap_Docker`** (the all-in-one container), not `redcap-db`.
- [x] **3a — compose:** built; socket mount uses **`${HOME}/.docker/run/docker.sock`**
  (macOS Docker Desktop has no `/var/run/docker.sock`); `build.ssh: [default]`.

---

## Phase 4: Documentation (still TODO)

- [x] **4a. NEW:** `CCTC_REDCap_Docker/redcap_docker_aio/README.md` — all-in-one quickstart
  (`cp .env.example .env` → `docker compose up -d`), the bare `docker run` form,
  URLs (`https://localhost:8443`, Mailhog `http://localhost:8025`), test creds
  (`test_admin` / `Testing123`), the **ephemeral-source** note, and the
  `cctc_mariadb_data` volume / durability-tuning note.  *(Replaces the dropped
  `minimal/README.md` — `minimal/` is being deleted.)*

- [x] **4b. NEW:** `CCTC_REDCap_Docker/cypress_runner/README.md` — runner
  quickstart: `docker compose build --ssh default` (why SSH), then with the AIO
  up `docker compose run --rm cypress [--spec ...]`; where the report lands; the
  socket + host-network requirement; `cypress open` runs on the host, not here.

- [x] **4c. MODIFY:** `CCTC_REDCap_Docker/README.md` (+ `CLAUDE.md`) — point to
  `redcap_docker_aio/` (REDCap) and `cypress_runner/` (tests) as the supported flow, distinct
  from the CI-oriented `redcap_docker/` stack.

---

## Verification

(Verified against the as-built all-in-one `redcap_docker_aio/` image + `cypress_runner/`, not
the original `minimal/` 3-container spec.)

- [x] **Image A builds & boots:** `cd redcap_docker_aio && docker compose up -d --build` →
  single container `CCTC_REDCap_Docker` boots; supervisord runs mariadbd +
  mailhog + apache; entrypoint logs show first-run DB init then Apache start.
- [x] **REDCap reachable:** `https://localhost:8443/` serves REDCap 15.5.36
  (HTTP 200); 12 test users seeded; Mailhog UI at `http://localhost:8025` (PHP
  mail → Mailhog confirmed).
- [x] **Recreate-safe on persisted volume:** `docker compose up -d` recreate
  re-uses the `cctc_mariadb_data` volume; entrypoint auths root with/without
  password (fresh vs persisted) so it no longer crashes on restart.
- [x] **Image B builds:** `cd cypress_runner && docker compose build --ssh default`
  → `npm ci` (672 pkgs via SSH) + `move_files` succeed; 308 feature files +
  fixtures baked.
- [x] **Single spec E2E:** `docker compose run --rm cypress --spec "…A.1.1.0100…"`
  passes; DB access via `docker exec CCTC_REDCap_Docker` works; report written to
  host `./results`.
- [x] **Multi-spec E2E (A/B/C/D):** 4-spec batch all green (14/14); plus a 2-spec
  batch re-run after the MariaDB durability tuning (still green, faster reseed).
- [x] **Full suite E2E (via small-batch sweep):** whole 248-spec suite run against
  the AIO — **~706/710 tests pass**; only **4 pre-existing suite flakes** (`A.6.4.0500`,
  `C.3.24.0505`, `D.113.200`, `D.113.300`), zero infra failures. Batching (6-spec
  chunks, fresh container each) avoided the memory thrashing. Flakes logged in
  `cypress_runner/flaky-tests.md`. (Full 248 in one run isn't viable on the 8 GB Air.)
- [x] **Re-run without REDCap restart:** multiple cypress runs against the same
  running `CCTC_REDCap_Docker` (confirms the two-stack, on-demand model).

---

## ✅ COMPLETE (closed 2026-07-03)

All phases done and both repos committed via merged PRs. **`CCTC_REDCap_Docker`**:
`redcap_docker_aio/` landed (PR #1, `feat/redcap-docker-aio-stack`), `minimal/` deleted,
README/CLAUDE updated, AIO-only CI workflow kept (`3fdc436`). **`redcap_cypress`**:
`cypress_runner/` committed (PR #104, `feat/cypress-runner-image`) and the whole CI
pipeline cut over to the AIO two-image stack (shared prebuilt GHCR images, 8-shard split).

Post-completion follow-ups (tracked in memory, not part of this plan's scope): the
rctf loading-overlay regression (`cctc_v1.0.5` → fixed in `cctc_v1.0.6`, jQuery `:visible`
vs `visibility:hidden`) and the combined-report shard-collision fix — both shipped
2026-07-03.

Build + full-suite validation were **done**. AIO container is left running (`docker ps`
→ `CCTC_REDCap_Docker`); restart with `cd redcap_docker_aio && docker compose up -d` if stopped.

1. **[x] Confirmed the 4 flakes** (isolated fresh-container reruns, `flaky-tests.md`
   updated): **A.6.4.0500** and **D.113.300** = flaky/pass-on-retry (passed on
   rerun); **C.3.24.0505** and **D.113.200** = consistent in isolation (failed
   again — need a spec/timing fix, not just a retry).
2. **[x] MOVED** `cypress_runner/` → `redcap_cypress/cypress_runner/`. Build context
   is now `redcap_cypress/` itself: Dockerfile `COPY . /work/redcap_cypress`,
   Dockerfile.dockerignore switched from whitelist to blacklist, compose `context: ..`
   still resolves correctly. README + parent CLAUDE.md/README paths updated;
   `redcap_cypress/.gitignore` ignores `cypress_runner/results/` + `cypress_runner/.env`.
   **Re-verified:** image rebuilds from the new context (SSH `npm ci` + move_files)
   and smoke spec `A.1.1.0100` passes (1/1).
3. **[x] DELETED** `minimal/` (nothing external referenced it).
4. **[x] COMMITTED** — spanned **two repos**, both landed via merged PRs:
   - `CCTC_REDCap_Docker`: new `redcap_docker_aio/`; `README.md` + `CLAUDE.md` edits; `minimal/`
     removed (PR #1). `cypress_runner/` lives **inside** the nested `redcap_cypress`
     repo, so it was NOT part of this repo's commit.
   - `redcap_cypress` (separate nested repo): new `cypress_runner/` folder +
     `.gitignore` edit (PR #104). Container-name override is a build-time `sed` in
     `cypress_runner/Dockerfile`, not a `cypress.config.js` source edit.
   - Unrelated untracked docs (AIPlans/, PLAN.md, various `.md`) were left
     uncommitted, as intended.

## Cleanup (do at the end)

- [x] **DELETE** `CCTC_REDCap_Docker/minimal/` — the 3-container REDCap stack,
  superseded by the all-in-one `redcap_docker_aio/`. Nothing referenced it; removed.

- [x] **MOVE** `CCTC_REDCap_Docker/cypress_runner/` → `redcap_cypress/cypress_runner/`
  (do **after** the B/C/D sweep finishes — the sweep driver references the current
  path). Build context becomes `redcap_cypress/` itself, so simplify: `COPY .
  /work/redcap_cypress` and drop the whitelist (just ignore node_modules,
  redcap_rsvc, test_db, .git, videos, results). Update Dockerfile COPY paths +
  compose `context: ..`. The `cypress.config.js` patch already lives in that repo,
  so the runner + the file it patches end up co-located.
  - **KEEP** `redcap_cypress/docker_bin/cypress-runner/` (the old bind-mount,
    multi-container, CI-emulation runner — it has the sharding helpers we may
    reuse). Add a one-line cross-reference in each README so it's clear which is
    which. Revisit deleting it only once AIO sharding is decided.
