#!/bin/sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Start message
echo -e "
     _____
  __|___  |__  _____   ____    ______  ______  ____  ____   _   _____
 |   ___|    ||     | |    \  |   ___||   ___||    ||    \ | | /     \\
 |   |  |    ||     \ |     \ |   ___||   ___||    ||     \| ||       |
 |______|  __||__|\__\|__|\__\|___|   |___|   |____||__/\____| \_____/
    |_____|   ${RED}PHP-FPM Container${NC}

  --------------------------------------------------------------------------
  ${BLUE}🐳  Container Configuration${NC}
"

# Get the current UID and GID of the container docker user
CURRENT_UID=$(id -u docker || echo -e "    ${RED}🛑  User 'docker' not found in container...${NC}")
CURRENT_GID=$(id -g docker || echo -e "    ${RED}🛑  Group 'docker' not found in container...${NC}")

# Check if USER_ID and GROUP_ID environment variables are set
if [ -n "${USER_ID}" ] && [ -n "${GROUP_ID}" ]; then
  # Check if the provided USER_ID and GROUP_ID are the same
  if [ "${USER_ID}" -ne "$CURRENT_UID" ] || [ "${GROUP_ID}" -ne "$CURRENT_GID" ]; then
    echo -e "    ${GREEN}✅  Changing UID and GID for user 'docker' to ${USER_ID}:${GROUP_ID}${NC}"
    # Change the UID of the docker user
    usermod -o -u "${USER_ID}" docker
    # Change the GID of the docker group
    groupmod -o -g "${GROUP_ID}" docker

    echo -e "    ${GREEN}✅  Updating permissions for user 'docker'...${NC}"

    # Handle files and directories owned by the old UID/GID
    chown -R "${USER_ID}":"${GROUP_ID}" /var/log/cron/ /etc/crontabs/ /var/spool/cron/

    chown -R "${USER_ID}":"${GROUP_ID}" /etc/supervisor/ /var/run/supervisor/ /var/log/supervisor/

    chown -R "${USER_ID}":"${GROUP_ID}" /usr/local/var/php/sessions /usr/local/lib/php/extensions /usr/local/etc/php/ /var/log/php-fpm/

    chown -R "${USER_ID}":"${GROUP_ID}" /tmp

    # Update the /var/www/ excluding read-only files
    find /var/www \
      -not -path "/var/www/.git*" \
      -not -path "/var/www/.env*" \
      -not -path "/var/www/node_modules/.bin/optipng*" \
      -not -path "/var/www/node_modules/image-webpack-loader/node_modules/imagemin-optipng/node_modules/.bin/optipng*" \
      -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"

    # Update the current UID and GID
    CURRENT_GID=$USER_ID
    CURRENT_UID=$GROUP_ID
  else
    echo -e "    ℹ️  UID and GID of docker user match with .env, skipping..."
  fi
else
  echo -e "    ℹ️  USER_ID and GROUP_ID .env variables not set. Using defaults..."
fi

# Check the environment variable and update the volume accordingly
case "${ENVIRONMENT:-}" in
production)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --include 'dist-wp' --include 'composer' --include 'wordpress/migrations/' --exclude '.env*' --exclude 'wordpress/uploads' /home/docker/ /var/www/
  cp -Rf /home/docker/dist-wp/wp-content/themes/Project-Name/images/logo*.svg /var/www/wordpress/uploads/
  rm -rf /var/www/node_modules
  rm -rf /var/www/html
  find /var/www -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -not -path "/var/www/node_modules/.bin/optipng*" \
    -not -path "/var/www/node_modules/image-webpack-loader/node_modules/imagemin-optipng/node_modules/.bin/optipng*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
staging)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --include 'dist-wp' --include 'composer' --include 'wordpress/migrations/' --exclude '.env*' --exclude 'wordpress/uploads' /home/docker/ /var/www/
  cp -Rf /home/docker/dist-wp/wp-content/themes/Project-Name/images/logo*.svg /var/www/wordpress/uploads/
  rm -rf /var/www/node_modules
  rm -rf /var/www/html
  find /var/www -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -not -path "/var/www/node_modules/.bin/optipng*" \
    -not -path "/var/www/node_modules/image-webpack-loader/node_modules/imagemin-optipng/node_modules/.bin/optipng*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
*)
  echo -e "    ℹ️  Environment is 'development'. Skipping application volume update..."
  find /var/www -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -not -path "/var/www/node_modules/.bin/optipng*" \
    -not -path "/var/www/node_modules/image-webpack-loader/node_modules/imagemin-optipng/node_modules/.bin/optipng*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
esac

# Run entrypoint scripts
if [ -d "/docker-entrypoint.d" ]; then

  echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Entrypoint Scripts${NC}
"
  for file in /docker-entrypoint.d/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
      echo -e "    ${GREEN}✅  Running: $file${NC}"
      su-exec docker "$file" >/dev/null
    fi
  done
fi

echo -e "
  --------------------------------------------------------------------------
  ${BLUE}ℹ️  Container Information${NC}

    OS:             $(. /etc/os-release && echo "${PRETTY_NAME}")
    Service:        PHP-FPM
    Environment:    $ENVIRONMENT

    PHP version:    $(php -v | head -n 1)
    PHP extensions: $(echo "$PHP_EXTENSIONS" | tr -d '"')

    Docker user:    docker
    Docker uid:     $CURRENT_UID
    Docker gid:     $CURRENT_GID

  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting Supervisord ...${NC}
  "

for file in /etc/supervisor/*.conf; do
  if [ -f "$file" ]; then
    echo -e "    ${GREEN}✅  Loading: $file${NC}"
  fi
done

# Start supervisord in the background
exec su-exec docker supervisord -c /etc/supervisord.conf &

echo -e "
  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting PHP-FPM ...${NC}

  --------------------------------------------------------------------------
  ${GREEN}🔥  Streaming logs ...${NC}
"

# Start command in the background
exec su-exec docker "$@" &

# Wait forever (or until canceled)
exec su-exec docker tail -f "/dev/null"
