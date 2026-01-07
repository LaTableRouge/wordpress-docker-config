FROM php:8.3-apache

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
    default-mysql-client \
    build-essential \
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
    soap \
    zip \
    gd \
    intl \
    mbstring

# Install WP-CLI globally via Composer
RUN composer global require wp-cli/wp-cli-bundle

ENV PATH="/root/.composer/vendor/bin:$PATH"

# Install WP-CLI Profile Command
RUN wp package install wp-cli/profile-command:@stable --allow-root

# Copy configuration files
COPY docker/conf/php.ini /usr/local/etc/php/conf.d/app.ini
COPY docker/conf/vhost.conf /etc/apache2/sites-available/000-default.conf
COPY docker/conf/apache.conf /etc/apache2/conf-available/z-app.conf
COPY docker/conf/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /usr/local/bin/entrypoint.sh

# Enable Apache modules and configuration
RUN a2enmod rewrite remoteip && \
    a2enconf z-app && \
    a2ensite 000-default

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
