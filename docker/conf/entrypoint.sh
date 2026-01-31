#!/bin/bash
set -e

# Helper function to create symlink (removes existing target first)
create_symlink() {
    local source="$1"
    local target="$2"
    local description="$3"
    
    if [ -e "$source" ]; then
        # Remove existing target if it exists
        if [ -e "$target" ] || [ -L "$target" ]; then
            rm -rf "$target" 2>/dev/null || unlink "$target" 2>/dev/null || true
        fi
        echo "Creating symlink: $target -> $source ($description)"
        ln -sf "$source" "$target"
    fi
}

# Helper function to check if directory is empty
is_dir_empty() {
    local dir="$1"
    [ ! -d "$dir" ] || [ -z "$(ls -A "$dir" 2>/dev/null)" ]
}

# Helper function to install npm dependencies
setup_npm() {
    local dir="$1"
    local node_modules_dir="$dir/node_modules"
    local bin_dir="$node_modules_dir/.bin"
    
    if [ ! -f "$dir/package.json" ]; then
        return 0
    fi
    
    echo "Checking npm setup for theme..."
    cd "$dir"
    
    if is_dir_empty "$node_modules_dir"; then
        echo "Installing npm dependencies in named volume..."
        npm install
    else
        echo "node_modules already exists in named volume"
    fi
    
    # Fix permissions for executables
    if [ -d "$bin_dir" ]; then
        echo "Fixing permissions for node_modules/.bin executables..."
        find "$bin_dir" -type f -exec chmod +x {} \; 2>/dev/null || true
        
        # Verify common executables
        for bin_file in vite wp-scripts; do
            if [ -f "$bin_dir/$bin_file" ]; then
                chmod +x "$bin_dir/$bin_file" 2>/dev/null || true
                if [ -x "$bin_dir/$bin_file" ]; then
                    echo "✓ $bin_file is executable"
                else
                    echo "⚠ Warning: $bin_file is not executable (chmod may not work on this filesystem)"
                fi
            fi
        done
    fi
}

# Helper function to install composer dependencies
setup_composer() {
    local dir="$1"
    local vendor_dir="$dir/vendor"
    
    if [ ! -f "$dir/composer.json" ]; then
        return 0
    fi
    
    echo "Checking composer setup for theme..."
    cd "$dir"
    
    if is_dir_empty "$vendor_dir"; then
        echo "Installing composer dependencies in named volume..."
        composer install
    else
        echo "vendor already exists in named volume"
    fi
}

# Helper function to fix husky hooks permissions
setup_husky() {
    local dir="$1"
    local husky_dir="$dir/.husky"
    
    if [ ! -d "$husky_dir" ]; then
        return 0
    fi
    
    echo "Fixing permissions for husky hooks..."
    find "$husky_dir" -type f -exec chmod +x {} \; 2>/dev/null || true
    if [ -d "$husky_dir/_" ]; then
        find "$husky_dir/_" -type f -exec chmod +x {} \; 2>/dev/null || true
    fi
    echo "✓ Husky hooks permissions fixed"
}

# Get theme name from environment variable, or extract from mounted volume path
if [ -z "$THEME_NAME" ]; then
    # Try to extract theme name from mounted volumes by checking /app/wp-content/themes
    # Find the first directory that's not a standard WordPress theme
    for theme_dir in /app/wp-content/themes/*/; do
        theme_name=$(basename "$theme_dir")
        # Skip default WordPress themes
        if [[ ! "$theme_name" =~ ^(twentytwenty|simppple|index\.php)$ ]]; then
            THEME_NAME="$theme_name"
            break
        fi
    done
fi

echo "Using theme: $THEME_NAME"

THEME_DIR="/app/wp-content/themes/$THEME_NAME"

# Create symlinks for theme files
create_symlink "$THEME_DIR/wp-config.php" "/app/wp-config.php" "wp-config.php"
create_symlink "$THEME_DIR/uploads" "/app/wp-content/uploads" "uploads directory"

# Setup theme dependencies (if theme directory exists)
if [ -d "$THEME_DIR" ]; then
    setup_npm "$THEME_DIR"
    setup_composer "$THEME_DIR"
    setup_husky "$THEME_DIR"
fi

# Configure git (editor + user if environment variables are set)
git config --global core.editor "vim"
if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_USER_EMAIL" ]; then
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    echo "Git configured: $GIT_USER_NAME <$GIT_USER_EMAIL>"
fi

# Execute the original command
exec "$@"
