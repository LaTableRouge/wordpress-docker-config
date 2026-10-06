#!/usr/bin/env bash
# Free disk space by removing the dependencies of the mounted theme and of the
# local plugin repos symlinked into wp-content/plugins. Run it before
# `docker compose down`; the entrypoint reinstalls everything on the next start.
#
# Run **inside** the container. Dry-run by default.
#
#   docker compose exec docker_app bash scripts/cleanup-deps.sh
#   docker compose exec docker_app bash scripts/cleanup-deps.sh live
#
# THEME_NAME comes from the environment (compose passes it from .env).

set -euo pipefail

LOCAL_PLUGINS_DIR=/local-plugins
THEME_NAME="${THEME_NAME:-}"

DRY_RUN=1
MODE_STR="TEST (dry-run)"
if [ "${1:-}" = "live" ]; then
    DRY_RUN=0
    MODE_STR="LIVE"
fi

yellow='\033[0;33m'
blue='\033[0;34m'
no_color='\033[0m'

if [ "$DRY_RUN" -eq 0 ]; then
    COLOR="$yellow"
else
    COLOR="$blue"
fi

TOTAL_KB=0

size_kb() {
    local kb
    kb=$(du -sk "$1" 2>/dev/null | awk 'NR==1 {print $1}')
    echo "${kb:-0}"
}

human() {
    awk -v kb="$1" 'BEGIN {
        split("KB MB GB TB", unit, " ")
        i = 1
        while (kb >= 1024 && i < 4) { kb /= 1024; i++ }
        printf "%.1f %s", kb, unit[i]
    }'
}

report() {
    printf "  %-12s %s\n" "$1" "$2"
}

# Theme node_modules and vendor are named-volume mount points: the directory
# itself cannot be removed, only emptied.
empty_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 0

    local kb
    kb=$(size_kb "$dir")
    TOTAL_KB=$((TOTAL_KB + kb))
    report "$(human "$kb")" "$dir"

    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

# Only delete what git ignores: some plugins commit vendor/ and need it to run.
remove_ignored_dir() {
    local repo="$1"
    local name="$2"
    local dir="$repo/$name"
    [ -d "$dir" ] || return 0

    if ! git -c safe.directory='*' -C "$repo" check-ignore -q "$name" 2>/dev/null; then
        report "kept" "$dir (tracked by git)"
        return 0
    fi

    local kb
    kb=$(size_kb "$dir")
    TOTAL_KB=$((TOTAL_KB + kb))
    report "$(human "$kb")" "$dir"

    if [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi
    rm -rf "$dir"
}

echo -e "${COLOR}========================================================================="
echo "   [Cleanup deps] ${MODE_STR}"
echo -e "=========================================================================${no_color}"

if [ -n "$THEME_NAME" ] && [ "$THEME_NAME" != "unused-theme" ]; then
    THEME_DIR="/app/wp-content/themes/$THEME_NAME"
    echo -e "\n${COLOR}Theme: ${THEME_NAME}${no_color}"
    if [ -d "$THEME_DIR" ]; then
        empty_dir "$THEME_DIR/node_modules"
        empty_dir "$THEME_DIR/vendor"
    else
        report "skipped" "$THEME_DIR (not found)"
    fi
else
    echo -e "\n${COLOR}Theme${no_color}"
    report "skipped" "no THEME_NAME set"
fi

if [ -d "$LOCAL_PLUGINS_DIR" ]; then
    for plugin_dir in "$LOCAL_PLUGINS_DIR"/*/; do
        [ -d "$plugin_dir" ] || continue
        plugin_dir="${plugin_dir%/}"

        echo -e "\n${COLOR}Plugin: $(basename "$plugin_dir")${no_color}"
        if [ ! -d "$plugin_dir/.git" ]; then
            report "skipped" "not a git checkout"
            continue
        fi
        remove_ignored_dir "$plugin_dir" node_modules
        remove_ignored_dir "$plugin_dir" vendor
    done
fi

echo ""
if [ "$TOTAL_KB" -eq 0 ]; then
    echo "Nothing to remove."
elif [ "$DRY_RUN" -eq 1 ]; then
    echo -e "${blue}$(human "$TOTAL_KB") would be freed. Re-run with: $0 live${no_color}"
else
    echo -e "${yellow}$(human "$TOTAL_KB") freed. The next container start reinstalls everything.${no_color}"
fi
