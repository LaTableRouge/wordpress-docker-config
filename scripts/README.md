# Scripts

Both run **inside** the container and are dry-run by default.

## `cleanup-deps.sh`

Frees disk space by removing the dependencies of the mounted theme and of the local plugin repos symlinked from `/local-plugins`. Run it before putting a project away; the entrypoint reinstalls everything on the next start.

```bash
docker compose exec docker_app bash scripts/cleanup-deps.sh        # report only
docker compose exec docker_app bash scripts/cleanup-deps.sh live
```

The dry-run prints what each directory holds and the total it would free. Nothing else is needed — it reads `THEME_NAME` from the environment.

Two things it will not touch: plugin directories that are not git checkouts, and any `node_modules` or `vendor` that git tracks rather than ignores, since some plugins commit `vendor/` and need it to run.

Expect the site to answer 502 on the next start for as long as the reinstall takes, because Apache boots only once the entrypoint is done.

## `search-replace-db.sh`

Replace production URLs with the local Docker URL after importing a remote database.

```bash
docker compose exec docker_app bash scripts/search-replace-db.sh
docker compose exec docker_app bash scripts/search-replace-db.sh live
```

Set these in `.env` (or export them before the command):

| Variable       | Required | Description                                              |
| -------------- | -------- | -------------------------------------------------------- |
| `PROD_DOMAIN`  | yes      | Production host, no scheme and no `www` (`example.com`)  |
| `LOCAL_DOMAIN` | no       | Local host, no scheme. Defaults to `APP_FQDN`            |
| `ADMIN_EMAIL`  | no       | If set, updates the WordPress `admin_email` option       |

`live` writes to the database. Keep a dump before you run it.
