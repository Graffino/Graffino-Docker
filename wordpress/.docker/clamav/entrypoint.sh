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
    |_____|   ${RED}ClamAV Container

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
    chown -R "${USER_ID}":"${GROUP_ID}" /run/clamav/ /var/log/clamav/ /var/lib/clamav/

    chown -R "${USER_ID}":"${GROUP_ID}" /tmp

    # Update the current UID and GID
    CURRENT_GID=$USER_ID
    CURRENT_UID=$GROUP_ID
  else
    echo -e "    ℹ️  UID and GID of docker user match with .env. Skipping...${NC}"
  fi
else
  echo -e "    ℹ️  USER_ID and GROUP_ID .env variables not set. Using defaults...${NC}"
fi

# Ensure we have some virus data, otherwise clamd refuses to start
if [ ! -f "/var/lib/clamav/main.cvd" ]; then
  echo -e "    ${GREEN}✅  Updating initial database via freshclam...${NC}"
  su-exec docker freshclam --foreground --stdout --user="docker" >/dev/null
fi

# Run entrypoint scripts
if [ -d "/docker-entrypoint.d" ]; then

  echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Entrypoint Scripts
"
  for file in /docker-entrypoint.d/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
      echo -e "    ${GREEN}✅  Running: $file${NC}"
      su-exec docker "$file" >>/dev/null
    fi
  done
fi

echo -e "
  --------------------------------------------------------------------------
  ${BLUE}ℹ️  Container Information${NC}

    OS:                $(. /etc/os-release && echo "${PRETTY_NAME}")
    Service:           ClamAV
    Environment:       $ENVIRONMENT

    ClamAV version:    $(clamscan --version | head -n 1)
    FreshClam version: $(freshclam --version | head -n 1)

    Docker user:       docker
    Docker uid:        $CURRENT_UID
    Docker gid:        $CURRENT_GID

  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting FreshClamd ...${NC}"

# Start freshclam in the background
exec su-exec docker freshclam --checks="${FRESHCLAM_CHECKS:-1}" --daemon --foreground --stdout --user="docker" &

echo -e "
  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting Clamd ...${NC}

  --------------------------------------------------------------------------
  ${GREEN}🔥  Streaming logs ...${NC}
"

# Start command in the background
exec su-exec docker "$@" &

# Wait forever (or until canceled)
exec su-exec docker tail -f "/dev/null"
