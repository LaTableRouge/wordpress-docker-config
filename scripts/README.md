# Scripts

## `search-replace-db.sh`

Replace production URLs with the local Docker URL after importing a remote database.

Run **inside** the container. Dry-run by default.

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
