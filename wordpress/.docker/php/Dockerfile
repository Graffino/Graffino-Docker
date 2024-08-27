# Get global arguments
ARG USERNAME=docker
ARG GROUPNAME=docker
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG ENVIRONMENT
ARG PHP_EXTENSIONS="gd mysqli pdo_mysql bcmath zip imagick"

# Get PHP image
FROM php:8.2-fpm-alpine3.19 AS main

ARG BUILD_DATE
ARG REVISION

# Labels
LABEL maintainer="Graffino Software <team@graffino.com>"

# OCI Labels
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.revision=${REVISION}
LABEL org.opencontainers.image.title="PHP-FPM Image"
LABEL org.opencontainers.image.vendor="Graffino Software <team@graffino.com>"
LABEL org.opencontainers.image.description="AnNoText - PHP-FPM Docker image"
LABEL org.opencontainers.image.source="https://github.com/Graffino/AnNoText"

# Set local arguments
ARG USERNAME
ARG GROUPNAME
ARG USER_ID
ARG GROUP_ID
ARG ENVIRONMENT
ARG PHP_EXTENSIONS

# Set environment variables
ENV USERNAME=${USERNAME:-docker}
ENV GROUPNAME=${GROUPNAME:-docker}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}
ENV ENVIRONMENT=${ENVIRONMENT:-production}

ENV PHP_EXTENSIONS=${PHP_EXTENSIONS:-"gd mysqli pdo_mysql bcmath zip imagick"}

ENV XDEBUG_MODE=${XDEBUG_MODE:-debug}
ENV XDEBUG_PORT=${XDEBUG_PORT:-9003}
ENV XDEBUG_IDEKEY=${XDEBUG_IDEKEY:-VSCODE}

ENV PHP_ERRORS=${PHP_ERRORS:-0}
ENV PHP_UPLOAD_SIZE=${PHP_UPLOAD_SIZE:-256M}
ENV PHP_MEMORYLIMIT=${PHP_MEMORYLIMIT:-512M}
ENV PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-30}
ENV PHP_MAX_INPUT_TIME=${PHP_MAX_INPUT_TIME:-30}

ENV PYTHONUNBUFFERED=1
ENV TZ=Europe/Bucharest

# Add NodeJS from image
COPY --from=node:20-alpine /usr/lib /usr/lib
COPY --from=node:20-alpine /usr/local/share /usr/local/share
COPY --from=node:20-alpine /usr/local/lib /usr/local/lib
COPY --from=node:20-alpine /usr/local/include /usr/local/include
COPY --from=node:20-alpine /usr/local/bin /usr/local/bin

# Add crontab file
COPY ./.docker/php/cron.d/crontab /tmp/crontab

SHELL ["/bin/ash", "-o", "pipefail", "-c"]
RUN <<EOF
  # Delete user and group with ID 1000 if they exist
  deluser --remove-home "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true
  delgroup "$(getent group 1000 | cut -d: -f1)" 2>/dev/null || true
  # Add user and group
  addgroup -g ${GROUP_ID} ${GROUPNAME}
  adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME}
  addgroup ${USERNAME} tty
  # Install build dependencies
  apk --no-cache add --virtual .build-deps \
    gcc \
    make \
    g++ \
    zlib-dev \
    autoconf \
    automake \
    libtool \
    nasm \
    libjpeg \
    jpeg-dev \
    libjpeg-turbo-dev \
    optipng \
    python3 \
    py3-pip \
    py3-setuptools
  # Install development dependencies & utilities
  apk --no-cache add --virtual .development-deps \
    mariadb-client \
    git \
    yarn \
    supervisor \
    busybox \
    fcgi \
    tini \
    shadow \
    su-exec \
    curl \
    mc
  # Link packages
  ln -sf python3 /usr/bin/python
  ln -sf pip /usr/bin/pip3
  # Install PHP extensions installer
  curl -sSLf -o /usr/local/bin/install-php-extensions \
  https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions
  chmod +x /usr/local/bin/install-php-extensions
  # Install PHP extensions
  # shellcheck disable=SC2046
  install-php-extensions $(eval echo "${PHP_EXTENSIONS}")
  # Install Composer
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  # Install WP-CLI
  curl -sSLf -o /usr/local/bin/wp \
  https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /usr/local/bin/wp
  # Install Crontab
  crontab /tmp/crontab
  mkdir /var/log/cron
  touch /var/log/cron/cron.log
  chown -R ${USER_ID}:${GROUP_ID} /var/log/cron/ /etc/crontabs/ /var/spool/cron/
  # Configure supervisor
  mkdir -p /etc/supervisor /var/run/supervisor/ /var/log/supervisor
  chown -R ${USER_ID}:${GROUP_ID} /etc/supervisor /var/run/supervisor /var/log/supervisor
  # Create php folders set permissions
  mkdir -p /var/log/php-fpm/ /usr/local/var/php/sessions
  chown -R ${USER_ID}:${GROUP_ID} /usr/local/var/php/sessions /usr/local/lib/php/extensions /usr/local/etc/php/ /var/log/php-fpm/
  chmod 755 /usr/local/lib/php/extensions/*
  # Create www folders & set permissions
  mkdir -p /var/www/node_modules /var/www/composer /var/www/dist-wp
  chown -R ${USER_ID}:${GROUP_ID} /var/www/
  chmod 755 /var/www/ /var/www/dist-wp/ /var/www/composer/
    # Set temp folder permissions
  chown -R ${USER_ID}:${GROUP_ID} /tmp
  chmod -R 0777 /tmp
  # Create healthcheck file & set permissions
  echo "<?php echo 'OK';" > /tmp/healthcheck.php
  chown ${USER_ID}:${GROUP_ID} /tmp/healthcheck.php
EOF

# Copy supervisor configuration files
COPY .docker/php/supervisor.d/supervisord.conf /etc/
COPY .docker/php/supervisor.d/conf.d/*.conf /etc/supervisor/

# Copy PHP configuration files
COPY .docker/php/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/
COPY .docker/php/conf.d/php.ini /usr/local/etc/php/

# Copy XDebug configuration files
COPY .docker/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/

# Copy entrypoint script
COPY .docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check to ensure PHP is running
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
  CMD sh -c 'SCRIPT_NAME=/healthcheck.php SCRIPT_FILENAME=/tmp/healthcheck.php REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1'

# Expose the PHP-FPM port
EXPOSE 9000

# Expose the Supervisord port
EXPOSE 9001

# Expose the XDebug port
EXPOSE 9003

# Set working directory
WORKDIR /var/www/

# Define volumes
VOLUME ["/var/www/node_modules"]
VOLUME ["/var/www/composer"]
VOLUME ["/var/www/"]

# Entry point
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

# Command
CMD ["php-fpm"]
