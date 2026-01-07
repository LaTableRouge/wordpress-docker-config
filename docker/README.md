# Docker Setup

This folder contains all Docker-related configuration files for the WordPress project.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Traefik Dockerized](https://github.com/LaTableRouge/dockerized) setup running (provides Traefik reverse proxy and MariaDB)
- [Sequel Ace](https://sequel-ace.com/) (for macOS) for database management

## Quick Start

### 1. Configure Environment

Create a `.env` file in the `root` folder:

```bash
PROJECT_NAME=your-project-name
APP_FQDN=local.your-project.com
APP_ENV=local
COMPOSER_ALLOW_SUPERUSER=1
```

### 2. Update Hosts File

Add to `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```text
127.0.0.1 local.your-project.com
```

### 3. Build and Start

```bash
docker compose build
docker compose up -d
```

### 4. Install Dependencies

```bash
docker compose exec docker_app composer install
```

### 5. Access the Website

- **Frontend:** <http://local.your-project.com>
- **Admin:** <http://local.your-project.com/wp-admin>

## Connecting Sequel Ace to MariaDB

Once your Docker containers are running, connect Sequel Ace using:

- **Host:** `127.0.0.1`
- **Port:** `3317` ⚠️ (Traefik Dockerized default, not 3306)
- **Username:** `root`
- **Password:** `root`
- **Database:** (leave empty or enter your database name)

> **Note:** If connection fails, ensure:
>
> - Docker Desktop is running
> - Traefik Dockerized containers are up
> - You're using port **3317**

## Common Commands

```bash
# Start/Stop
docker compose up -d
docker compose down

# Access container shell
docker compose exec docker_app bash

# Run WP-CLI commands
docker compose exec docker_app wp --info --allow-root

# View logs
docker compose logs -f docker_app
```

## Troubleshooting

**Website shows 404:**

- Check Traefik is running: `docker compose ps` (in dockerized project)
- Verify `.env` file has correct `APP_FQDN` value
- Check Apache logs: `docker compose exec docker_app tail -f /var/log/apache2/error.log`

**Database connection issues:**

- Verify MariaDB is running in Traefik Dockerized setup
- Test connection: `docker compose exec docker_app mysql -h mariadb -u root -proot -e "SHOW DATABASES;"`
