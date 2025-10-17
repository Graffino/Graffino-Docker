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

echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Laravel Configuration${NC}

    ${GREEN}✅  Configure storage folders...${NC}"

# Ensure the directories are created and have the correct permissions
if [ ! -d /var/www/storage/framework/cache/data ]; then
  mkdir -p /var/www/storage/framework/cache/data
  chown -R "${USER_ID}":"${GROUP_ID}" /var/www/storage/framework/cache/data
  chmod -R 755 /var/www/storage/framework/cache/data
fi

if [ ! -d /var/www/storage/framework/sessions ]; then
  mkdir -p /var/www/storage/framework/sessions
  chown -R "${USER_ID}":"${GROUP_ID}" /var/www/storage/framework/sessions
  chmod -R 755 /var/www/storage/framework/sessions
fi

if [ ! -d /var/www/storage/app/public ]; then
  mkdir -p /var/www/storage/app/public
  chown -R "${USER_ID}":"${GROUP_ID}" /var/www/storage/app/public
  chmod -R 755 /var/www/storage/app/public
fi

# Run artisan commands if the vendor directory and autoload.php exist
if [ -f /var/www/artisan ] && [ -f /var/www/vendor/autoload.php ]; then
  cd /var/www

  if [ ! -L /var/www/public/storage ]; then
    echo -e "    ${GREEN}✅  Run artisan to Link storage folder...${NC}"
    php artisan storage:link
  fi

  case "${ENVIRONMENT:-}" in
  production | staging)
    echo -e "    ${GREEN}✅  Run artisan to execute migrations...${NC}"

    if ! php artisan migrate --force; then
      echo -e "    ${RED}🛑  Migrations failed...${NC}"
    fi

    echo "    ${GREEN}✅  Run artisan to rebuild cache...${NC}"
    # Run optimize and storage:link if the symlink does not exist
    php artisan optimize:clear
    php artisan optimize
    ;;
  *)
    echo -e "    ℹ️  Environment is 'development'. Skipping migrations and cache rebuild..."
    ;;
  esac
fi

echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Update application volume${NC}

"
# Check the environment variable and update the volume accordingly
case "${ENVIRONMENT:-}" in
production)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --exclude '.env*' --exclude 'storage' /home/docker/ /var/www/
  rm -rf /var/www/node_modules
  rm -rf /var/www/html
  find /var/www \
    -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
staging)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --exclude '.env*' --exclude 'storage' /home/docker/ /var/www/
  rm -rf /var/www/node_modules
  rm -rf /var/www/html
  find /var/www \
    -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
*)
  echo -e "    ℹ️  Environment is 'development'. Skipping application volume update..."
  find /var/www \
    -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
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
