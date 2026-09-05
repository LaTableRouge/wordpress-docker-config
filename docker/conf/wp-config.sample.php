<?php
/**
 * Sample wp-config.php for local Docker (shared-theme mode).
 *
 * Copy this file to your theme root as wp-config.php, then:
 * - set DB_NAME
 * - generate new salts: https://api.wordpress.org/secret-key/1.1/salt/
 *
 * The container entrypoint symlinks this file to /app/wp-config.php.
 *
 * MariaDB comes from Traefik Dockerized (host `mariadb`, user/password `root`).
 */

define('WP_DEVELOPMENT_MODE', 'core');
define('WP_ENVIRONMENT_TYPE', 'local');
define('WP_DEBUG', true);
define('WP_DEBUG_LOG', true);
define('WP_DEBUG_DISPLAY', true);
define('SCRIPT_DEBUG', true);

define('COMPRESS_CSS', false);
define('COMPRESS_SCRIPTS', false);
define('CONCATENATE_SCRIPTS', false);
define('ENFORCE_GZIP', false);

define('WP_CACHE', false);

define('ALLOW_UNFILTERED_UPLOADS', false);
define('DISALLOW_UNFILTERED_HTML', false);
define('WP_AUTO_UPDATE_CORE', 'minor');
define('EMPTY_TRASH_DAYS', 10);
define('WP_POST_REVISIONS', 10);
define('DISALLOW_FILE_EDIT', true);

define('WP_MAX_MEMORY_LIMIT', '640M');
define('WP_MEMORY_LIMIT', '640M');

define('DB_NAME', 'my-site');
define('DB_USER', 'root');
define('DB_PASSWORD', 'root');
define('DB_HOST', 'mariadb');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

$table_prefix = 'wp_';

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once ABSPATH . 'wp-settings.php';
