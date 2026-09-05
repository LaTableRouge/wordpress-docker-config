#!/usr/bin/env bash
# Replace production URLs with the local Docker URL.
# Dry-run by default. Pass `live` to apply.
#
#   docker compose exec docker_app bash scripts/search-replace-db.sh
#   docker compose exec docker_app bash scripts/search-replace-db.sh live
#
# Configure via environment (see .env.example):
#   PROD_DOMAIN   production host without scheme or www (example.com)
#   LOCAL_DOMAIN  local host without scheme (defaults to APP_FQDN)
#   ADMIN_EMAIL   optional admin email to set after replace

set -euo pipefail

PROD_DOMAIN="${PROD_DOMAIN:-}"
LOCAL_DOMAIN="${LOCAL_DOMAIN:-${APP_FQDN:-}}"
ADMIN_EMAIL="${ADMIN_EMAIL:-}"

if [ -z "$PROD_DOMAIN" ] || [ -z "$LOCAL_DOMAIN" ]; then
    echo "Set PROD_DOMAIN and LOCAL_DOMAIN (or APP_FQDN) before running."
    echo "Example: PROD_DOMAIN=example.com LOCAL_DOMAIN=local.example.com"
    exit 1
fi

if command -v wp >/dev/null 2>&1; then
    WP=(wp --allow-root)
elif [ -x vendor/bin/wp ]; then
    WP=(vendor/bin/wp --allow-root)
else
    echo "WP-CLI not found (wp or vendor/bin/wp)."
    exit 1
fi

MODE=()
MODE_STR="TEST (dry-run)"
if [ "${1:-}" = "live" ]; then
    MODE_STR="LIVE"
else
    MODE=(--dry-run)
fi

yellow='\033[0;33m'
blue='\033[0;34m'
no_color='\033[0m'

if [ "$MODE_STR" = "LIVE" ]; then
    COLOR="$yellow"
else
    COLOR="$blue"
fi

replace() {
    local from="$1"
    local to="$2"
    echo ""
    echo -e "${COLOR}========================================================================================================="
    echo "   [WP Search Replace] ${MODE_STR} — ${from} => ${to}"
    echo -e "=========================================================================================================${no_color}"
    "${WP[@]}" search-replace "$from" "$to" --all-tables "${MODE[@]}"
}

echo -e "${COLOR}Production: ${PROD_DOMAIN}  →  Local: ${LOCAL_DOMAIN}${no_color}"

if [ -n "$ADMIN_EMAIL" ] && [ "$MODE_STR" = "LIVE" ]; then
    echo ""
    echo -e "${COLOR}Setting admin_email to ${ADMIN_EMAIL}${no_color}"
    "${WP[@]}" option update admin_email "$ADMIN_EMAIL"
fi

replace "https://www.${PROD_DOMAIN}" "http://${LOCAL_DOMAIN}"
replace "http://www.${PROD_DOMAIN}" "http://${LOCAL_DOMAIN}"
replace "https://${PROD_DOMAIN}" "http://${LOCAL_DOMAIN}"
replace "http://${PROD_DOMAIN}" "http://${LOCAL_DOMAIN}"
replace "//www.${PROD_DOMAIN}" "//${LOCAL_DOMAIN}"

if [ "$MODE_STR" != "LIVE" ]; then
    echo ""
    echo -e "${blue}Dry-run finished. Re-run with: $0 live${no_color}"
fi
