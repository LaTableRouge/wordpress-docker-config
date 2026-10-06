# WordPress Docker Development Environment

Docker stack for local WordPress: PHP 8.3, Apache, Node.js 24, Composer, WP-CLI, APCu, Imagick, and optional Xdebug. Traefik and MariaDB come from [Traefik Dockerized](https://github.com/LaTableRouge/dockerized).

One `docker-compose.yml`. Behaviour is switched from `.env`:

| Mode            | When                                                       | `.env`                            |
| --------------- | ---------------------------------------------------------- | --------------------------------- |
| **Standalone**  | The repo _is_ the WordPress site                           | Leave `THEME_NAME` unset          |
| **Shared core** | One WordPress install, theme mounted from a sibling folder  | Set `THEME_NAME` and `THEME_PATH` |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose v2.30+)
- [Traefik Dockerized](https://github.com/LaTableRouge/dockerized) running — provides the `traefik` network and MariaDB. That network is `external: true`, so Compose will not start without it.
- SSH keys on the host if you commit from inside the container. `~/.ssh` is mounted; create that folder first or Docker will create an empty one.

## Quick start

```bash
cp .env.example .env          # then set PROJECT_NAME and APP_FQDN
echo "127.0.0.1 local.my-site.com" | sudo tee -a /etc/hosts
docker compose build
docker compose up -d
```

Open `http://local.my-site.com`, admin at `/wp-admin`. First start can take a minute while WordPress and dependencies install.

Database access from the host (Sequel Ace, port **3317**) is covered in [`docker/README.md`](docker/README.md).

## Configuration

Everything is driven by `.env` — see [`.env.example`](.env.example).

| Variable          | Default               | Effect                                                            |
| ----------------- | --------------------- | ----------------------------------------------------------------- |
| `PROJECT_NAME`    | _required_            | Compose project name and Traefik router name                      |
| `APP_FQDN`        | _required_            | Hostname Traefik routes to the container; must match `/etc/hosts`  |
| `THEME_NAME`      | unset                 | Theme folder to mount. Unset means standalone mode                |
| `THEME_PATH`      | `./docker`            | **Parent** folder holding the theme, not the theme folder itself   |
| `PLUGIN_PATH`     | `../../WP-plugins`    | Parent folder for local plugin repos                              |
| `WP_VERSION`      | `6.8.2`               | Core version fetched on first start. `latest` for the newest       |
| `SKIP_WP_DOWNLOAD`| unset                 | Set to `1` to never download core                                 |
| `INSTALL_XDEBUG`  | `false`               | Bakes Xdebug into the image — **requires a rebuild**              |
| `XDEBUG_MODE`     | `off`                 | e.g. `develop,debug`. Applied on restart                          |
| `VITE_PORT`       | `5173`                | Host port mapped to Vite. Change it if two stacks collide          |
| `GIT_USER_NAME`   | unset                 | Set with `GIT_USER_EMAIL` to configure git inside the container    |
| `GIT_USER_EMAIL`  | unset                 | See above                                                         |

`search-replace-db.sh` reads three more variables, documented in [`scripts/README.md`](scripts/README.md).

## What happens on every start

The entrypoint ([`docker/conf/entrypoint.sh`](docker/conf/entrypoint.sh)) is idempotent and runs on every `up`:

1. **Downloads WordPress** if `wp-load.php` and `wp-includes/version.php` are both missing, then extracts it with `cp -n` so existing files (`docker/`, `.env`, an existing `wp-content`) are never overwritten.
2. **Symlinks the theme's `wp-config.php` and `uploads/`** into the WordPress root (shared mode only).
3. **Installs npm and Composer dependencies** for the project root and the theme, when the directory is empty or the lockfile is newer than the installed tree. A failure logs a warning instead of killing the container.
4. **Symlinks local plugin repos** from `/local-plugins` into `wp-content/plugins`, after Composer has run.
5. **Installs plugin dependencies** for git-checkout plugins only — bundled plugins are left alone.
6. **Fixes Husky hook permissions** on the theme and on plugins.
7. **Configures git** if `GIT_USER_NAME` and `GIT_USER_EMAIL` are set.

## Shared mode

One WordPress core, one theme at a time. Core, Composer plugins, and extra themes stay in the core repo; project-specific `wp-config.php` and `uploads/` live in the theme. With this stack in `WP-core/<site>/`, the defaults resolve like this:

```text
WP-core/
└── my-site/      # WordPress core + this compose file
WP-themes/
└── my-theme/     # THEME_NAME=my-theme, THEME_PATH=../../WP-themes
    ├── wp-config.php   # required — see docker/conf/wp-config.sample.php
    ├── uploads/        # required — media for this project
    ├── package.json    # optional
    └── composer.json   # optional
WP-plugins/
└── my-plugin/    # optional, see "Local plugins" below
```

Switch project by changing `PROJECT_NAME` / `THEME_NAME` / `APP_FQDN` in `.env` and recreating the container. If `THEME_NAME` is unset, Compose mounts `docker/unused-theme` so it does not overlay `wp-content/themes`.

> Set `THEME_NAME` in `.env`. There is no auto-detect: an unset value means standalone mode.

### wp-config conventions

Start from [`docker/conf/wp-config.sample.php`](docker/conf/wp-config.sample.php): `DB_HOST` is `mariadb`, `DB_USER` and `DB_PASSWORD` are both `root`, `DB_NAME` is a database you create yourself. **Generate fresh salts before first use.**

### Local plugins

For plugins you are developing, uncomment a volume in `docker-compose.yml` — mounted under `/local-plugins`, **not** directly in `wp-content/plugins`:

```yaml
- ${PLUGIN_PATH:-../../WP-plugins}/my-plugin:/local-plugins/my-plugin
```

Composer only unlinks symlinks, so a Composer package of the same name replaces the link instead of emptying your repo — which is exactly what happens when the repo is bind-mounted in place. Real directories that are a mount or a git checkout are never replaced.

Install ordinary plugins with Composer (`wpackagist`) in the WordPress root instead.

## Standalone mode

Drop `docker/`, `docker-compose.yml`, and `.env` into a full WordPress project, or into an empty folder and let the first start fetch core. The project root is mounted at `/app` and the entrypoint skips the theme symlinks.

## Dependencies and disk usage

Theme `node_modules` and `vendor` live in named volumes, which avoids bind-mount permission issues. The entrypoint installs into them when they are empty or when a lockfile is newer than the installed tree.

That adds up to well over a gigabyte per project. To reclaim it on a project you are putting away, run `cleanup-deps.sh` before stopping the container — see [`scripts/README.md`](scripts/README.md). The next start reinstalls everything.

## Xdebug

Off by default to keep the image small. Set `INSTALL_XDEBUG=true` and `XDEBUG_MODE=develop,debug` in `.env`, then `docker compose build`.

Your IDE listens on port `9003`. `host.docker.internal` is mapped via `extra_hosts`, so Linux behaves like Docker Desktop. The debugger only starts when triggered (`xdebug.start_with_request = trigger`).

## Commands

```bash
# Shell, logs, WP-CLI (always --allow-root in this image)
docker compose exec docker_app bash
docker compose logs -f docker_app
docker compose exec docker_app wp --info --allow-root

# Theme work (shared mode)
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && npm run build"
```

Two helper scripts cover rewriting URLs after a database import and freeing dependency disk space: [`scripts/README.md`](scripts/README.md).

## Troubleshooting

<details>
<summary><strong>Site returns 502 Bad Gateway</strong></summary>

Traefik reaches the container but nothing listens on port 80 yet. Apache starts only after the entrypoint has installed every dependency, so a cold start serves 502 for as long as that takes — minutes on a first install. `docker compose logs -f docker_app` shows what it is working on; Apache is up once you see `resuming normal operations`.

If it never gets there, the entrypoint is stuck or failing earlier in that log.
</details>

<details>
<summary><strong>Pages take several seconds to render</strong></summary>

WordPress makes loopback HTTP calls to its own `APP_FQDN` (wp-cron, Site Health). That name only exists in the *host's* `/etc/hosts`, so from inside the container it hits DNS and hangs. Compose maps it to `127.0.0.1` via `extra_hosts`; confirm with:

```bash
docker compose exec docker_app curl -s -o /dev/null -w '%{time_total}s\n' "http://${APP_FQDN}/"
```
</details>

<details>
<summary><strong>Site returns 404</strong></summary>

Traefik Dockerized must be up, `APP_FQDN` must match your `/etc/hosts` entry, and the `traefik` network must exist (`docker network ls`).
</details>

<details>
<summary><strong>Container will not start</strong></summary>

Run `docker compose logs docker_app`. Confirm Traefik Dockerized is running *before* `docker compose up`.
</details>

<details>
<summary><strong>WordPress was not downloaded</strong></summary>

Check `docker compose logs docker_app` for the wordpress.org URL — the container needs outbound HTTPS. Restart once the network is back, or set `SKIP_WP_DOWNLOAD=1` and install core yourself.
</details>

<details>
<summary><strong>Theme not detected</strong></summary>

Set `THEME_NAME` and `THEME_PATH` in `.env`, then look for `Using theme` in the logs.
</details>

<details>
<summary><strong>Database connection fails</strong></summary>

Host `mariadb`, user and password `root`. Test from the container with `mysql -h mariadb -u root -proot -e "SHOW DATABASES;"`. From the host, Sequel Ace uses port **3317** — see [`docker/README.md`](docker/README.md).
</details>

<details>
<summary><strong>Dependencies look stale, or npm/Composer permission errors</strong></summary>

```bash
docker compose down -v && docker compose build --no-cache && docker compose up -d
```

`-v` deletes the named volumes; dependencies reinstall on the next start.
</details>

<details>
<summary><strong>Port 5173 already allocated</strong></summary>

Set `VITE_PORT` in `.env` to a free host port.
</details>

<details>
<summary><strong>Git over SSH fails inside the container</strong></summary>

Check the mount with `docker compose exec docker_app ls -la /root/.ssh`, then `ssh -T git@github.com`.
</details>

## Customization

- **PHP** — edit `docker/conf/php.ini`, then `docker compose restart docker_app`
- **Apache** — edit `docker/conf/vhost.conf` or `docker/conf/apache.conf`, then restart
- **PHP version** — change `FROM php:8.3-apache` in `docker/Dockerfile`, then `docker compose build --no-cache`

These are bind-mounted by Compose, not baked into the image, so a restart is enough. `entrypoint.sh` *is* copied in, so changing it needs `docker compose build`.

## Project structure

```text
.
├── docker/
│   ├── Dockerfile
│   ├── unused-theme/            # placeholder mount when THEME_NAME is unset
│   ├── conf/
│   │   ├── entrypoint.sh        # runs on start
│   │   ├── php.ini
│   │   ├── xdebug.ini
│   │   ├── vhost.conf
│   │   ├── apache.conf
│   │   └── wp-config.sample.php
│   └── README.md                # image internals, Sequel Ace
├── scripts/
│   ├── cleanup-deps.sh          # frees dependency disk space on demand
│   ├── search-replace-db.sh
│   └── README.md
├── docker-compose.yml
├── .env.example
└── README.md
```

## License

Boilerplate template. Customize it for each project.
