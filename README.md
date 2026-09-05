# WordPress Docker Development Environment

Docker stack for local WordPress: PHP 8.3, Apache, Node.js, Composer, WP-CLI, Traefik, and MariaDB (via [Traefik Dockerized](https://github.com/LaTableRouge/dockerized)).

One `docker-compose.yml`. Behaviour is switched from `.env`:

| Mode            | When                                                       | `.env`                            |
| --------------- | ---------------------------------------------------------- | --------------------------------- |
| **Standalone**  | The repo _is_ the WordPress site                           | Leave `THEME_NAME` unset          |
| **Shared core** | One WordPress install, theme mounted from a sibling folder | Set `THEME_NAME` and `THEME_PATH` |

If the project folder has no WordPress (`wp-load.php` missing), the first container start downloads the official zip from wordpress.org and extracts it **without overwriting** existing files (`docker/`, `.env`, an existing `wp-content`, …).

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose)
- [Traefik Dockerized](https://github.com/LaTableRouge/dockerized) running — provides the `traefik` network and MariaDB
- SSH keys on the host if you commit from inside the container (`~/.ssh` is mounted; create that folder first or Docker will create an empty one)

The `traefik` network is `external: true`. Compose will not start without it.

## Disk layout (shared mode)

Theme and plugin bind mounts are relative to the compose file. With this stack living in `WP-core/<site>/`, the defaults (`../../WP-themes`, `../../WP-plugins`) resolve like this:

```text
WP-core/
└── my-site/                 # WordPress core + this compose file
WP-themes/
└── my-theme/                # THEME_NAME=my-theme
WP-plugins/
└── my-plugin/               # optional bind mount
```

## Quick start

1. Copy environment defaults:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env`: `PROJECT_NAME` and `APP_FQDN`. For a shared theme, also set `THEME_NAME` and `THEME_PATH=../../WP-themes`.

3. Add the hostname:

   ```text
   # /etc/hosts (macOS/Linux) or C:\Windows\System32\drivers\etc\hosts
   127.0.0.1 local.my-site.com
   ```

4. Build and start:

   ```bash
   docker compose build
   docker compose up -d
   ```

   First start can take a minute if WordPress has to be downloaded.

5. Open `http://local.my-site.com` (or your `APP_FQDN`).

Admin: `http://local.my-site.com/wp-admin`.

Docker-only steps (Sequel Ace, logs, WP-CLI) are in [`docker/README.md`](docker/README.md).

## First-start WordPress download

The entrypoint looks for `/app/wp-load.php` and `/app/wp-includes/version.php`. If both exist, nothing is fetched.

Otherwise it downloads `wordpress-${WP_VERSION}.zip` (default `6.8.2`) and copies the `wordpress/` tree into the project directory with `cp -n` (no clobber). Set `WP_VERSION=latest` for the current release.

```bash
WP_VERSION=6.8.2
SKIP_WP_DOWNLOAD=1
```

A folder that already has WordPress core skips this step.

## Standalone mode

Drop `docker/`, `docker-compose.yml`, and `.env` into a full WordPress project (or an empty folder and let the first start fetch core). The project root is mounted at `/app`.

The entrypoint will:

- download WordPress if core is missing
- run `composer install` / `npm install` at the project root when those manifests exist
- fix Husky hook permissions at the root
- set up git-checkout plugins the same way as shared mode

Expose Vite with `VITE_PORT` (default `5173`) if two stacks would collide.

## Shared mode

One WordPress core, one theme at a time. Core, Composer plugins, and extra themes stay in the core repo. Project-specific `wp-config.php` and `uploads/` live in the theme.

In `.env`:

```bash
THEME_NAME=my-theme
THEME_PATH=../../WP-themes
```

If `THEME_NAME` is unset, compose mounts `docker/unused-theme` so it does not overlay `wp-content/themes`. `THEME_PATH` is the **parent** folder (`WP-themes`), not the theme folder itself.

### Theme layout

```text
my-theme/
├── wp-config.php     # required — see docker/conf/wp-config.sample.php
├── uploads/          # required — media for this project
├── style.css
├── functions.php
├── package.json      # optional
├── composer.json     # optional
└── ...
```

On start, the entrypoint:

- downloads WordPress if the core folder is empty
- symlinks `wp-config.php` → `/app/wp-config.php` and `uploads/` → `/app/wp-content/uploads`
- installs theme npm/Composer deps into named volumes
- installs npm/Composer only for **git-checkout** plugins (bundled plugins are left alone)
- fixes Husky permissions on the theme and on plugins
- configures git if `GIT_USER_NAME` and `GIT_USER_EMAIL` are set

Set `THEME_NAME` in `.env`. There is no auto-detect.

### wp-config conventions

Use [`docker/conf/wp-config.sample.php`](docker/conf/wp-config.sample.php) as a starting point:

- `DB_HOST` = `mariadb` (Traefik Dockerized service name)
- `DB_USER` / `DB_PASSWORD` = `root` / `root`
- `DB_NAME` = a database you create in MariaDB
- generate new salts before first use

### External plugins

Uncomment a volume in `docker-compose.yml`:

```yaml
- ${PLUGIN_PATH:-../../WP-plugins}/my-plugin:/app/wp-content/plugins/my-plugin
```

Use bind mounts for plugins you are developing. Install ordinary plugins with Composer (`wpackagist`) in the WordPress root.

Switch theme by changing `THEME_NAME` / `APP_FQDN` / `PROJECT_NAME` in `.env` and recreating the container.

## Xdebug

Off by default (faster image). In `.env`:

```bash
INSTALL_XDEBUG=true
XDEBUG_MODE=develop,debug
```

Then rebuild: `docker compose build`. IDE listens on port `9003`. `host.docker.internal` is set via `extra_hosts` so Linux works the same as Docker Desktop.

Requests start the debugger only when triggered (`xdebug.start_with_request = trigger`).

## Common commands

```bash
docker compose exec docker_app bash
docker compose exec docker_app wp --info --allow-root
docker compose exec docker_app wp plugin list --allow-root
docker compose exec docker_app wp theme list --allow-root
```

Theme work (shared mode):

```bash
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && bash"
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && npm install"
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && npm run build"
```

Git inside the container (`~/.ssh` is mounted):

```bash
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && git status"
```

Import a remote database, then rewrite URLs:

```bash
docker compose exec docker_app bash scripts/search-replace-db.sh
docker compose exec docker_app bash scripts/search-replace-db.sh live
```

See [`scripts/README.md`](scripts/README.md).

## Features

- PHP 8.3 + Apache, Node.js 24, Composer, WP-CLI
- APCu and Imagick
- Downloads WordPress on first start if the folder has no install
- Vite port (`5173` by default)
- Traefik labels (`APP_FQDN`)
- Optional Xdebug (`INSTALL_XDEBUG` in `.env`)
- Entrypoint: theme symlinks, root + theme + plugin deps, lockfile refresh, Husky, git
- Named volumes for theme `node_modules` / `vendor` (avoids bind-mount permission issues)

## Named volumes

Theme `node_modules` and `vendor` live in named volumes. The entrypoint runs `npm install` / `composer install` when the directory is empty or when `package-lock.json` / `composer.lock` is newer than the installed tree.

If deps look stuck:

```bash
docker compose down -v
docker compose up -d
```

`-v` deletes those volumes. You will reinstall theme dependencies on the next start.

## Troubleshooting

**WordPress was not downloaded** — check `docker compose logs docker_app` for the download URL. The container needs outbound HTTPS to wordpress.org. Restart after the network is back, or set `SKIP_WP_DOWNLOAD=1` and install core yourself.

**Theme not detected** — set `THEME_NAME` and `THEME_PATH` in `.env`. Check logs for `Using theme`.

**404** — Traefik Dockerized must be up, `APP_FQDN` must match `/etc/hosts`, and the `traefik` network must exist (`docker network ls`).

**Database** — host `mariadb`, user `root`, password `root`. From the app container: `mysql -h mariadb -u root -proot -e "SHOW DATABASES;"`. Sequel Ace on the host uses port **3317** (see [`docker/README.md`](docker/README.md)).

**Git SSH** — `docker compose exec docker_app ls -la /root/.ssh` then `ssh -T git@github.com`.

**Vite / 5173 already allocated** — set `VITE_PORT` in `.env` to a free host port.

**Permission errors with npm/Composer** — `docker compose down -v && docker compose build --no-cache && docker compose up -d`.

**Container will not start** — `docker compose logs docker_app`. Confirm Traefik is running before `up`.

## Customization

- PHP: `docker/conf/php.ini` then `docker compose restart docker_app`
- Apache: `docker/conf/vhost.conf` or `docker/conf/apache.conf`, then restart
- PHP version: change `FROM php:8.3-apache` in `docker/Dockerfile` and rebuild (`docker compose build --no-cache`)

## Project structure

```text
.
├── docker/
│   ├── Dockerfile
│   ├── unused-theme/          # placeholder bind mount when THEME_NAME is unset
│   ├── conf/
│   │   ├── entrypoint.sh
│   │   ├── php.ini
│   │   ├── xdebug.ini
│   │   ├── vhost.conf
│   │   ├── apache.conf
│   │   └── wp-config.sample.php
│   └── README.md
├── docker-compose.yml
├── scripts/
│   ├── search-replace-db.sh
│   └── README.md
├── .env.example
└── README.md
```

## License

Boilerplate template. Customize it for each project.
