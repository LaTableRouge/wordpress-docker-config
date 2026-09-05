# Docker Setup

Modes, first-start WordPress download, theme layout, and Xdebug: [root README](../README.md).

## Sequel Ace → MariaDB

MariaDB comes from [Traefik Dockerized](https://github.com/LaTableRouge/dockerized), not from this compose file.

- **Host:** `127.0.0.1`
- **Port:** `3317` (not 3306)
- **Username:** `root`
- **Password:** `root`
- **Database:** leave empty, or `DB_NAME` from `wp-config.php`

From the app container:

```bash
docker compose exec docker_app mysql -h mariadb -u root -proot -e "SHOW DATABASES;"
```

## Commands

```bash
docker compose up -d
docker compose down
docker compose exec docker_app bash
docker compose exec docker_app wp --info --allow-root
docker compose logs -f docker_app
```

Always pass `--allow-root` to WP-CLI.

Search-replace after a DB import: [`../scripts/README.md`](../scripts/README.md).
