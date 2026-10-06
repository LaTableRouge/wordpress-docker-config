#!/bin/bash
set -e

create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"

    if [ -e "$source" ]; then
        if [ -e "$target" ] || [ -L "$target" ]; then
            rm -rf "$target" 2>/dev/null || unlink "$target" 2>/dev/null || true
        fi
        echo "Creating symlink: $target -> $source ($description)"
        ln -sf "$source" "$target"
    fi
}

is_dir_empty() {
    local dir="$1"
    [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]
}

# Local plugin repos are mounted here and symlinked into wp-content/plugins.
# Composer only unlinks symlinks, so a composer package with the same name can
# never empty the mounted repo (it would if the repo were mounted in place).
LOCAL_PLUGINS_DIR=/local-plugins
WP_PLUGINS_DIR=/app/wp-content/plugins

prune_local_plugin_links() {
    for link in "$WP_PLUGINS_DIR"/*; do
        [ -L "$link" ] || continue
        case "$(readlink "$link")" in
            "$LOCAL_PLUGINS_DIR"/*) ;;
            *) continue ;;
        esac
        if [ ! -e "$link" ]; then
            echo "Removing stale local plugin link: $link"
            rm -f "$link"
        fi
    done
}

link_local_plugins() {
    [ -d "$LOCAL_PLUGINS_DIR" ] || return 0
    mkdir -p "$WP_PLUGINS_DIR"

    for source in "$LOCAL_PLUGINS_DIR"/*/; do
        [ -d "$source" ] || continue
        source="${source%/}"
        local name target
        name=$(basename "$source")
        target="$WP_PLUGINS_DIR/$name"

        if [ -L "$target" ]; then
            [ "$(readlink "$target")" = "$source" ] && continue
            rm -f "$target"
        elif [ -e "$target" ]; then
            if mountpoint -q "$target" 2>/dev/null || [ -d "$target/.git" ]; then
                echo "⚠ $target is a mount or git checkout — not replacing it with $source"
                continue
            fi
            echo "Replacing $target with local repo $source"
            rm -rf "$target"
        fi

        echo "Linking local plugin: $target -> $source"
        ln -s "$source" "$target"
    done
}

setup_npm() {
    local dir="$1"
    local label="${2:-project}"
    local node_modules_dir="$dir/node_modules"
    local bin_dir="$node_modules_dir/.bin"

    if [ ! -f "$dir/package.json" ]; then
        return 0
    fi

    echo "Checking npm setup for $label..."
    cd "$dir"

    if is_dir_empty "$node_modules_dir"; then
        echo "Installing npm dependencies for $label..."
        # A fresh install can run "prepare" (husky) before .bin links exist
        npm install || { echo "npm install failed for $label — retrying once..."; npm install; }
    elif [ -f "$dir/package-lock.json" ] && [ -f "$node_modules_dir/.package-lock.json" ] \
        && [ "$dir/package-lock.json" -nt "$node_modules_dir/.package-lock.json" ]; then
        echo "package-lock.json is newer than node_modules for $label — updating..."
        npm install
    else
        echo "node_modules already up to date for $label"
    fi

    if [ -d "$bin_dir" ]; then
        find "$bin_dir" -type f -exec chmod +x {} \; 2>/dev/null || true

        for bin_file in vite wp-scripts; do
            if [ -f "$bin_dir/$bin_file" ] && [ ! -x "$bin_dir/$bin_file" ]; then
                echo "⚠ Warning: $bin_file is not executable (chmod may not work on this filesystem)"
            fi
        done
    fi
}

setup_composer() {
    local dir="$1"
    local label="${2:-project}"
    local vendor_dir="$dir/vendor"

    if [ ! -f "$dir/composer.json" ]; then
        return 0
    fi

    echo "Checking composer setup for $label..."
    cd "$dir"

    if is_dir_empty "$vendor_dir"; then
        echo "Installing composer dependencies for $label..."
        composer install
    elif [ -f "$dir/composer.lock" ] && [ -f "$vendor_dir/composer/installed.json" ] \
        && [ "$dir/composer.lock" -nt "$vendor_dir/composer/installed.json" ]; then
        echo "composer.lock is newer than vendor for $label — updating..."
        composer install
    else
        echo "vendor already up to date for $label"
    fi
}

setup_husky() {
    local dir="$1"
    local label="${2:-project}"
    local husky_dir="$dir/.husky"

    if [ ! -d "$husky_dir" ]; then
        return 0
    fi

    echo "Fixing permissions for husky hooks ($label)..."
    find "$husky_dir" -type f -exec chmod +x {} \; 2>/dev/null || true
    if [ -d "$husky_dir/_" ]; then
        find "$husky_dir/_" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi
}

setup_project() {
    local dir="$1"
    local label="$2"

    if [ ! -d "$dir" ]; then
        return 0
    fi

    setup_npm "$dir" "$label"
    setup_composer "$dir" "$label"
    setup_husky "$dir" "$label"
}

wordpress_is_installed() {
    [ -f /app/wp-load.php ] && [ -f /app/wp-includes/version.php ]
}

install_wordpress() {
    if [ "${SKIP_WP_DOWNLOAD:-}" = "1" ] || [ "${SKIP_WP_DOWNLOAD:-}" = "true" ]; then
        echo "SKIP_WP_DOWNLOAD is set — not fetching WordPress"
        return 0
    fi

    if wordpress_is_installed; then
        echo "WordPress already present — skipping download"
        return 0
    fi

    local version="${WP_VERSION:-latest}"
    local url
    if [ "$version" = "latest" ]; then
        url="https://wordpress.org/latest.zip"
    else
        url="https://wordpress.org/wordpress-${version}.zip"
    fi

    echo "No WordPress install found. Downloading ${url}..."
    local tmp
    tmp=$(mktemp -d)

    if ! curl -fL --retry 3 --retry-delay 2 "$url" -o "$tmp/wordpress.zip"; then
        echo "⚠ Failed to download WordPress from $url"
        rm -rf "$tmp"
        return 1
    fi

    if ! unzip -q "$tmp/wordpress.zip" -d "$tmp"; then
        echo "⚠ Failed to unzip WordPress archive"
        rm -rf "$tmp"
        return 1
    fi

    if [ ! -d "$tmp/wordpress" ]; then
        echo "⚠ Unexpected zip layout (missing wordpress/ directory)"
        rm -rf "$tmp"
        return 1
    fi

    echo "Extracting WordPress into /app (existing files are kept)..."
    cp -an "$tmp/wordpress/." /app/
    rm -rf "$tmp"

    if wordpress_is_installed; then
        echo "✓ WordPress ${version} is in place"
    else
        echo "⚠ WordPress extract finished but wp-load.php is missing"
        return 1
    fi
}

install_wordpress || echo "⚠ WordPress download failed — restart the container when the network is available"

prune_local_plugin_links

# THEME_NAME is required for shared mode. Auto-detect is a last resort only.
if [ -z "$THEME_NAME" ] && [ -d /app/wp-content/themes ]; then
    for theme_dir in /app/wp-content/themes/*/; do
        [ -d "$theme_dir" ] || continue
        theme_name=$(basename "$theme_dir")
        if [[ ! "$theme_name" =~ ^(twenty[a-z-]*|index\.php|\.unused|unused-theme)$ ]]; then
            THEME_NAME="$theme_name"
            echo "⚠ THEME_NAME was not set; auto-detected '$THEME_NAME'. Set THEME_NAME in .env to make this explicit."
            break
        fi
    done
fi

if [ -n "$THEME_NAME" ] && [ "$THEME_NAME" != "unused-theme" ] && [ "$THEME_NAME" != ".unused" ]; then
    echo "Using theme: $THEME_NAME"
    THEME_DIR="/app/wp-content/themes/$THEME_NAME"

    if [ ! -d "$THEME_DIR" ]; then
        echo "⚠ Theme directory not found: $THEME_DIR"
    else
        create_symlink "$THEME_DIR/wp-config.php" "/app/wp-config.php" "wp-config.php"
        create_symlink "$THEME_DIR/uploads" "/app/wp-content/uploads" "uploads directory"
        setup_project "$THEME_DIR" "theme" || echo "⚠ Warning: dependency setup failed for theme"
    fi
else
    echo "No THEME_NAME set — standalone mode (no theme symlinks)"
fi

setup_project /app "project root" || echo "⚠ Warning: dependency setup failed for project root"

# After composer, so the links replace any copy composer just installed
link_local_plugins

if [ -d /app/wp-content/plugins ]; then
    for plugin_dir in /app/wp-content/plugins/*/; do
        [ -d "$plugin_dir" ] || continue
        plugin_name=$(basename "$plugin_dir")
        setup_husky "$plugin_dir" "plugin $plugin_name"

        if [ -d "$plugin_dir/.git" ]; then
            setup_npm "$plugin_dir" "plugin $plugin_name" || echo "⚠ Warning: npm setup failed for plugin $plugin_name"
            setup_composer "$plugin_dir" "plugin $plugin_name" || echo "⚠ Warning: composer setup failed for plugin $plugin_name"
        fi
    done
fi

if command -v git >/dev/null 2>&1; then
    git config --global core.editor "vim"
    if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email "$GIT_USER_EMAIL"
        echo "Git configured: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    fi
fi

exec "$@"
