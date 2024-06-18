# Get NodeJS image
FROM node:18-alpine AS node

# Get PHP image
FROM php:8.2-fpm-alpine3.16

# Set environment variables for user creation
ARG USERNAME=docker
ARG GROUPNAME=${USERNAME}
ARG USER_ID=${USER_ID:-1000}
ARG GROUP_ID=${USER_ID:-1000}
ENV USERNAME=docker
ENV GROUPNAME=${USERNAME}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}

# Set PHP environment variables
ARG PHP_EXTENSIONS=${PHP_EXTENSIONS:-"gd mysqli bcmath pdo_mysql zip xdebug opcache"}
ENV PHP_EXTENSIONS=${PHP_EXTENSIONS:-"gd mysqli bcmath pdo_mysql zip xdebug opcache"}

ENV XDEBUG_CONFIG=${XDEBUG_CONFIG:-"mode=off"}
ENV XDEBUG_MODE=${XDEBUG_MODE:-"off"}
ENV XDEBUG_HOST=${XDEBUG_HOST:-"host.docker.internal"}
ENV XDEBUG_PORT=${XDEBUG_PORT:-"9003"}
ENV XDEBUG_TRIGGER=${XDEBUG_TRIGGER:-"DOCKER"}

ENV PHP_ERRORS=${PHP_ERRORS:-"0"}
ENV PHP_UPLOAD_SIZE=${PHP_UPLOAD_SIZE:-"256M"}
ENV PHP_MEMORYLIMIT=${PHP_MEMORYLIMIT:-"512M"}
ENV PHP_MAX_EXECUTION_TIME=${PHP_MAX_EXECUTION_TIME:-"30"}
ENV PHP_MAX_INPUT_TIME=${PHP_MAX_INPUT_TIME:-"30"}

ENV PYTHONUNBUFFERED=1
ENV TZ=Europe/Bucharest

# Create a non-root user with USER_ID and GID from build arguments
RUN apk --no-cache add sudo shadow && \
  addgroup -g ${GROUP_ID} ${GROUPNAME} && \
  adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME} && \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install development tools, Git, MariaDB client, NodeJS, Yarn, Python and pip
# Install dependencies
RUN apk --no-cache add --virtual .build-deps \
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
  libjpeg-turbo-dev

RUN apk --no-cache add --virtual .development-deps \
  optipng \
  git \
  mariadb-client \
  curl \
  yarn

RUN apk add --update --no-cache python3 && \
  ln -sf python3 /usr/bin/python && \
  python3 -m ensurepip && \
  pip3 install --no-cache --upgrade pip setuptools

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install WP CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
  chmod +x wp-cli.phar && \
  mv wp-cli.phar /usr/local/bin/wp && \
  chmod +x /usr/local/bin/wp

# Install utilities
RUN apk --no-cache add vim mc fcgi

# Install cron and create a log file
RUN apk --no-cache add busybox-suid && \
  mkdir /var/log/cron && \
  touch /var/log/cron/cron.log && \
  chown -R ${USERNAME}:${GROUPNAME} /var/log/cron/

# Create a script run wp cron periodically
RUN echo "* * * * * /usr/local/bin/wp --path=/var/www/dist-wp/ cron event run --due-now >> /var/log/cron/cron.log 2 >& 1" > /tmp/crontab && \
  crontab /tmp/crontab

# Install NodeJS
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/share /usr/local/share
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/include /usr/local/include
COPY --from=node /usr/local/bin /usr/local/bin

# Build PHP Extensions
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/
RUN chmod uga+x /usr/local/bin/install-php-extensions && sync
RUN install-php-extensions $(eval echo ${PHP_EXTENSIONS})

# Copy PHP and Xdebug configuration files
COPY .docker/php/php-fpm.d/www.conf /usr/local/etc/php-fpm.d/
COPY .docker/php/conf.d/php.ini /usr/local/etc/php/
COPY .docker/php/conf.d/xdebug.ini /usr/local/etc/php/conf.d/

# Create logs directory & set permissions
RUN mkdir -p /var/log/php-fpm/ /usr/local/var/php/sessions && \
  chown -R ${USERNAME}:${GROUPNAME} /var/log/php-fpm/ /usr/local/var/php/sessions /usr/local/lib/php/extensions /usr/local/etc/php/ && \
  chmod 755 /usr/local/lib/php/extensions/*

# Create www folders & set permissions
RUN mkdir -p /var/www/node_modules /var/www/composer /var/www/dist-wp && \
  chown -R ${USERNAME}:${GROUPNAME} /var/www/ && \
  chmod 755 /var/www/ && \
  chmod 755 /var/www/dist-wp/ && \
  chmod 755 /var/www/composer/

# Delete build deps
# RUN apk del .build-deps

# Switch to non-root user
USER ${USERNAME}

# Set working directory
WORKDIR /var/www/

# Define volumes
VOLUME ["/var/www/node_modules"]
VOLUME ["/var/www/composer"]

# Expose the PHP-FPM port
EXPOSE 9000

# Health check to ensure PHP is running
RUN echo "<?php echo 'OK';" > /tmp/healthcheck.php

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD sh -c 'SCRIPT_NAME=/healthcheck.php SCRIPT_FILENAME=/tmp/healthcheck.php REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1'

# Create a script to start both crond and clamd
COPY .docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

# Start the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD [""]
