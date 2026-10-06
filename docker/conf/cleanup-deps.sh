#!/bin/bash
# Run by the compose pre_stop hook: frees disk space by removing the theme and
# local plugin dependencies. The entrypoint reinstalls them on the next start.

empty_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 0
    echo "Removing contents of $dir"
    # Theme deps are named volumes: the mount point itself can't be removed
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
}

remove_ignored_dir() {
    local repo="$1"
    local name="$2"
    local dir="$repo/$name"
    [ -d "$dir" ] || return 0
    # Only delete what git ignores: some plugins commit vendor/ and need it to run
    if git -c safe.directory='*' -C "$repo" check-ignore -q "$name" 2>/dev/null; then
        echo "Removing $dir"
        rm -rf "$dir"
    else
        echo "Keeping $dir (not ignored by git)"
    fi
}

if [ -n "${THEME_NAME:-}" ] && [ "$THEME_NAME" != "unused-theme" ] && [ "$THEME_NAME" != ".unused" ]; then
    THEME_DIR="/app/wp-content/themes/$THEME_NAME"
    empty_dir "$THEME_DIR/node_modules"
    empty_dir "$THEME_DIR/vendor"
fi

# Same condition as the entrypoint's reinstall: git checkouts only
for plugin_dir in /local-plugins/*/; do
    [ -d "$plugin_dir/.git" ] || continue
    plugin_dir="${plugin_dir%/}"
    remove_ignored_dir "$plugin_dir" node_modules
    remove_ignored_dir "$plugin_dir" vendor
done

exit 0
