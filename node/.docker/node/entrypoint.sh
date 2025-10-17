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
    |_____|   ${RED}NodeJS Container${NC}

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
  ${BLUE}🤝  Update application volume${NC}
"
# Check the environment variable and update the volume accordingly
case "${ENVIRONMENT:-}" in
production)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --exclude '.env*' /home/docker/ /var/www/
  find /var/www \
    -not -path "/var/www/.git*" \
    -not -path "/var/www/.env*" \
    -print0 | xargs -0 chown "${USER_ID}":"${GROUP_ID}"
  ;;
staging)
  echo -e "    ${GREEN}✅  Update application volume data...${NC}"
  rsync -aEzhP --delete-before --include '.docker' --exclude '.env*' /home/docker/ /var/www/
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

    OS:          $(. /etc/os-release && echo "${PRETTY_NAME}")
    Service:     NodeJS
    Environment: $ENVIRONMENT

    Node version: $(node -v)
    NPM version:  $(npm -v)

    Docker user:  docker
    Docker uid:   $CURRENT_UID
    Docker gid:   $CURRENT_GID

  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting NodeJS ...${NC}

  --------------------------------------------------------------------------
  ${GREEN}🔥  Streaming logs ...${NC}
"

# Start command in the foreground
exec su-exec docker "$@"
