# REDCap Standalone Docker

Single-container Docker environment for running REDCap (v15.5.33) with MariaDB, MailHog, and phpMyAdmin — all managed by supervisord.

## Project Structure

```
.
├── docker-compose.yml    # Single service exposing all ports
├── Dockerfile            # All-in-one image: PHP/Apache + MariaDB + MailHog + phpMyAdmin
├── entrypoint.sh         # Initializes MariaDB + REDCap DB, then starts supervisord
├── supervisord.conf      # Process manager config for MariaDB, Apache, MailHog
├── phpmyadmin.conf       # Apache VirtualHost for phpMyAdmin on port 8081
├── .env                  # Environment config (version, ports, credentials)
├── .env.example          # Template for .env
├── database.php          # Template for REDCap DB connection config
├── CreateUsers.sql       # Seeds 11 test users into the database
├── php.ini               # Custom PHP configuration
├── mycert.crt / .key     # Self-signed SSL certificates
└── redcap_source/        # REDCap source files (not committed)
```

## Services & Ports

All services run in a single container (`redcap-app`):

| Service    | Process Manager  | Default Port | URL                     |
|------------|------------------|--------------|-------------------------|
| REDCap     | Apache (supervisord) | 8443 (HTTPS) | https://localhost:8443  |
| REDCap     | Apache (supervisord) | 8080 (HTTP)  | http://localhost:8080   |
| MariaDB    | supervisord      | 3400         | -                       |
| MailHog    | supervisord      | 8025 (UI)    | http://localhost:8025   |
| phpMyAdmin | Apache VirtualHost | 8081       | http://localhost:8081   |

## Common Commands

```bash
# Build and start (single container)
docker compose up --build

# Start without rebuild (data persists in volumes)
docker compose up

# Stop
docker compose down

# Full reset (destroys database volume)
docker compose down -v && docker compose up --build

# View logs
docker compose logs -f app

# Access the container shell
docker exec -it redcap-app bash

# Access the database directly
docker exec -it redcap-app mysql -u root -proot redcap
```

## Environment Variables (.env)

| Variable             | Default    | Description                                      |
|----------------------|------------|--------------------------------------------------|
| REDCAP_VERSION       | 15.5.33    | Must match directory name under `redcap_source/`  |
| MYSQL_ROOT_PASSWORD  | root       | MariaDB root password                            |
| MYSQL_DATABASE       | redcap     | Database name                                    |
| REDCAP_SALT          | 12345678   | REDCap hash salt (do NOT change after first run) |
| REDCAP_HTTP_PORT     | 8080       | Host port for HTTP                               |
| REDCAP_HTTPS_PORT    | 8443       | Host port for HTTPS                              |
| MYSQL_PORT           | 3400       | Host port for MariaDB                            |
| MAILHOG_SMTP_PORT    | 1025       | Host port for MailHog SMTP                       |
| MAILHOG_UI_PORT      | 8025       | Host port for MailHog web UI                     |
| PHPMYADMIN_PORT      | 8081       | Host port for phpMyAdmin                         |

## Test Users

All users have password: `Testing123`

| Username     | Role          | Super Admin |
|-------------|---------------|-------------|
| test_admin  | Administrator | Yes         |
| test_user1  | Regular User  | No          |
| test_user2  | Regular User  | No          |
| test_user3  | Regular User  | No          |
| test_user4  | Regular User  | No          |
| test_monitor| Monitor       | No          |
| test_dm     | Data Manager  | No          |
| test_de1    | Data Entry    | No          |
| test_de2    | Data Entry    | No          |
| test_de3    | Data Entry    | No          |
| test_depi   | Data Entry PI | No          |

## Key Implementation Details

- **Single container**: All services (Apache, MariaDB, MailHog) run inside one container, managed by `supervisord`.
- **phpMyAdmin**: Served by Apache on port 8081 via a separate VirtualHost (not a separate process).
- **Database auto-init**: `entrypoint.sh` starts MariaDB temporarily, checks for `redcap_config` table. If absent, runs `install.sql`, `install_data.sql`, and `CreateUsers.sql`. Then stops MariaDB and hands off to supervisord.
- **MariaDB connects via localhost**: No Docker networking needed. PHP connects to `localhost` via Unix socket.
- **SSL**: Self-signed certs mounted into the container. Browser warnings are expected.
- **Email**: All outgoing email is captured by MailHog (nothing leaves the system). PHP uses `mhsendmail` to route mail to `localhost:1025`.
- **Data persistence**: MariaDB data stored in named Docker volume (`mariadb_data`). Rebuilding the image does NOT reset data; use `docker compose down -v` for a full reset.
- **PHP extensions**: mysqli, GD, zip, imagick (for PDF support in REDCap 13+).
- **ImageMagick policy**: Modified to allow PDF read/write operations.

## Editing Guidelines

- When modifying `Dockerfile`, `entrypoint.sh`, `supervisord.conf`, or `phpmyadmin.conf`, always rebuild with `docker compose up --build`.
- The `redcap_source/` directory is COPYed at build time, not mounted. Changes require a rebuild.
- Do not commit `.env` (contains credentials) or `redcap_source/` (licensed software).
- `REDCAP_SALT` must never change after the first database initialization.
