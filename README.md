# WordPress Docker Development Environment

A Docker-based development environment for WordPress with automatic theme integration, dependency management, and git support.

## Prerequisites

- Docker and Docker Compose installed
- **Recommended**: [Traefik Dockerized](https://github.com/LaTableRouge/dockerized) setup for reverse proxy and database
- SSH keys set up on your host machine (for git operations)

> **Note**: It's better to use the [Traefik Dockerized](https://github.com/LaTableRouge/dockerized) configuration which provides Traefik reverse proxy, MariaDB database, and other services in a unified setup.

## Quick Start

1. **Create a `.env` file** in the root directory:

```env
# Project Configuration
PROJECT_NAME=myproject
APP_FQDN=local.myproject.com

# Git Configuration (optional, for git operations inside container)
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com
```

2. **Build and start the containers**:

```bash
docker compose build
docker compose up -d
```

3. **Access your WordPress site**:

Visit `http://local.myproject.com` (or your configured `APP_FQDN`)

## Using an External Theme

If your theme is located outside the WordPress installation:

### Why This Structure?

This setup is designed to use a **single WordPress instance for all your theme projects**. Only the theme changes between projects, while WordPress core, plugins, and additional themes are managed via Composer. This approach:

- Keeps WordPress core clean and reusable
- Allows easy switching between theme projects
- Manages plugins and themes via Composer dependencies
- Isolates project-specific configuration and uploads per theme

### Theme Structure

Your external theme **must** include the following structure:

```
my-theme/
├── wp-config.php          # WordPress configuration (project-specific)
├── uploads/               # Media uploads directory (project-specific)
├── style.css
├── functions.php
├── index.php
├── package.json           # npm dependencies (optional)
├── composer.json          # Composer dependencies (optional)
└── ... (other theme files)
```

**Important**: The `wp-config.php` and `uploads/` directory must be in your theme root. The entrypoint script will automatically symlink them to the WordPress root.

### Setup Steps

1. **Set the theme name** in your `.env` file:

```env
THEME_NAME=my-theme
```

2. **Update the theme volume path** in `docker-compose.yml`:

```yaml
volumes:
  # Update this path to match your theme location
  - ../../WP-themes/${THEME_NAME}:/app/wp-content/themes/${THEME_NAME}
```

3. **The entrypoint script will automatically**:
   - Detect your theme
   - Create symlinks for `wp-config.php` and `uploads` directory
   - Install npm dependencies (if `package.json` exists)
   - Install Composer dependencies (if `composer.json` exists)
   - Fix permissions for executables and husky hooks

**Note**: Plugins and additional themes should be installed via Composer in your WordPress root `composer.json`, not as external volumes (unless they're custom/private plugins).

## Using an External Plugin

External plugins are useful for **custom or private plugins** that you're actively developing. For standard WordPress plugins, it's recommended to install them via Composer in your WordPress root `composer.json`.

### When to Use External Plugins

- Custom plugins you're developing
- Private plugins not available via Composer/Packagist
- Plugins that need to be shared across multiple projects

### Setup Steps

1. **Add plugin volumes** to `docker-compose.yml`:

```yaml
volumes:
  # Add your external plugins here
  - ../../WP-plugins/my-plugin:/app/wp-content/plugins/my-plugin
```

2. **Restart the container**:

```bash
docker compose restart docker_app
```

**Note**: Standard WordPress plugins should be installed via Composer using `wpackagist` or similar repositories to keep your WordPress installation clean and manageable.

## Common Commands

### Access Container

```bash
docker compose exec docker_app bash
```

### WP-CLI

```bash
docker compose exec docker_app wp --info
docker compose exec docker_app wp plugin list
docker compose exec docker_app wp theme list
```

### Theme Development

```bash
# Enter container and navigate to theme
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && bash"

# Install dependencies
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && npm install"
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && composer install"

# Build assets
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && npm run build"
```

### Git Operations

Git is configured to work inside the container. SSH keys are mounted from your host (`~/.ssh`).

```bash
# Enter container and navigate to theme
docker compose exec docker_app bash -c "cd /app/wp-content/themes/${THEME_NAME} && bash"

# Then use git normally
git status
git add .
git commit -m "Your commit message"
git push
```

**Note**: Make sure `GIT_USER_NAME` and `GIT_USER_EMAIL` are set in your `.env` file for commits.

## Features

- **PHP 8.3** with Apache
- **Node.js & npm** for frontend development
- **Composer** for PHP dependencies
- **WP-CLI** pre-installed
- **Automatic theme integration** with symlinks
- **Named volumes** for `node_modules` and `vendor` (fixes permission issues)
- **Git support** with SSH key mounting
- **Husky hooks** support for git workflows
- **Traefik** integration for reverse proxy

## Troubleshooting

### Permission Issues

If you encounter permission errors with npm/Composer:

```bash
docker compose down -v
docker compose build --no-cache
docker compose up -d
```

### Git SSH Issues

```bash
# Verify SSH keys are mounted
docker compose exec docker_app ls -la /root/.ssh

# Test SSH connection
docker compose exec docker_app ssh -T git@github.com
```

### Theme Not Detected

1. Set `THEME_NAME` explicitly in your `.env` file
2. Verify the theme path in `docker-compose.yml` matches your actual theme location
3. Check container logs: `docker compose logs docker_app | grep "Using theme"`

### Container Won't Start

```bash
# Check logs
docker compose logs docker_app

# Verify Traefik network exists
docker network ls | grep traefik

# Rebuild
docker compose build --no-cache
docker compose up -d
```

## Customization

### PHP Configuration

Edit `docker/conf/php.ini` and restart:

```bash
docker compose restart docker_app
```

### Apache Configuration

Edit `docker/conf/vhost.conf` or `docker/conf/apache.conf` and restart:

```bash
docker compose restart docker_app
```

### PHP Version

Edit `docker/Dockerfile` and change the base image:

```dockerfile
FROM php:8.2-apache  # Change version here
```

Then rebuild:

```bash
docker compose build --no-cache
docker compose up -d
```

## Project Structure

```
.
├── docker/
│   ├── Dockerfile              # Main Docker image definition
│   ├── conf/
│   │   ├── entrypoint.sh      # Container entrypoint script
│   │   ├── php.ini            # PHP configuration
│   │   ├── vhost.conf         # Apache virtual host
│   │   └── apache.conf        # Apache configuration
│   └── README.md              # Docker-specific documentation
├── docker-compose.yml         # Docker Compose configuration
├── .env                       # Environment variables (create this)
└── README.md                  # This file
```

## License

This is a boilerplate template. Customize as needed for your project.
