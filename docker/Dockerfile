FROM php:8.3-apache

ARG INSTALL_XDEBUG=false

ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /app

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -qy --no-install-recommends \
    git \
    openssh-client \
    gnupg \
    unzip \
    zip \
    curl \
    wget \
    libxml2-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libonig-dev \
    libmagickwand-dev \
    default-mysql-client \
    build-essential \
    vim \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Node.js and npm
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    chmod +x /usr/local/bin/composer

# Install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg && \
    docker-php-ext-install -j$(nproc) \
    opcache \
    pdo_mysql \
    mysqli \
    zip \
    gd \
    intl \
    mbstring

# APCu (php.ini already enables apc.enable_cli) and Imagick (WP image editor)
RUN pecl install apcu && \
    printf '\n' | pecl install imagick && \
    docker-php-ext-enable apcu imagick

# Xdebug (INSTALL_XDEBUG=true in .env, then rebuild)
RUN if [ "$INSTALL_XDEBUG" = "true" ]; then \
      pecl install xdebug && \
      docker-php-ext-enable xdebug; \
    fi

# Install WP-CLI globally via Composer
RUN composer global require wp-cli/wp-cli-bundle

ENV PATH="/root/.composer/vendor/bin:$PATH"

RUN wp package install wp-cli/profile-command:@stable --allow-root

COPY docker/conf/entrypoint.sh /usr/local/bin/entrypoint.sh

# php.ini / vhost / apache.conf are bind-mounted by compose.
# Placeholder so a2enconf succeeds at build time.
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    touch /etc/apache2/conf-available/z-app.conf && \
    a2enmod rewrite remoteip && \
    a2enconf z-app && \
    a2ensite 000-default

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
