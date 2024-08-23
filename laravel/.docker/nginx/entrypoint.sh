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
    |_____|   ${RED}Nginx Container${NC}

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
    chown -R "${USER_ID}":"${GROUP_ID}" /var/log/nginx/ /etc/nginx/ /var/cache/nginx/ /var/run/ /etc/nginx/templates/

    chown -R "${USER_ID}":"${GROUP_ID}" /tmp

    # Update the /var/www/ excluding .git
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

    OS:            $(. /etc/os-release && echo "${PRETTY_NAME}")
    Service:       Nginx
    Environment:   $ENVIRONMENT

    Nginx version: $(nginx -v 2>&1)

    Docker user:   docker
    Docker uid:    $CURRENT_UID
    Docker gid:    $CURRENT_GID

  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting Nginx ...${NC}

  --------------------------------------------------------------------------
  ${GREEN}🔥  Streaming logs ...${NC}
"

# Start command in the foreground
exec su-exec docker "$@"
