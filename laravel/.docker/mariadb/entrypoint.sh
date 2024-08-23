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
    |_____|   ${RED}MariaDB Container${NC}

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
    chown -R "${USER_ID}":"${GROUP_ID}" /var/lib/mysql /etc/my.cnf.d/ /run/mysqld

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

# Initialize the data directory if it's not already initialized
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo -e "    ${GREEN}✅  Initializing MariaDB data directory...${NC}"
  mariadb-install-db --datadir=/var/lib/mysql --auth-root-authentication-method=normal --skip-test-db --user=docker >/dev/null

  # Start MariaDB server
  mysqld_safe --datadir=/var/lib/mysql --user=docker >/dev/null &

  # Wait for MariaDB to start
  sleep 5

  # Create database, set usernames and passwords
  mariadb -uroot <<-EOF
    CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%';
    FLUSH PRIVILEGES;
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
EOF

  # Shut down MariaDB server
  mysqladmin -uroot -p"${DB_ROOT_PASSWORD}" shutdown >/dev/null
else
  echo -e "    ℹ️  MariaDB data already initialized. Skipping..."
fi

# Unset sensitive environment variables
DB_DATABASE=""
DB_USERNAME=""
DB_PASSWORD=""
DB_ROOT_PASSWORD=""

# Run entrypoint scripts
if [ -d "/docker-entrypoint.d" ]; then

  echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Entrypoint Scripts${NC}
"
  for file in /docker-entrypoint.d/*; do
    if [ -f "$file" ] && [ -x "$file" ]; then
      echo -e "    ${GREEN}✅  Running: $file"
      su-exec docker "$file" >>/dev/null
    fi
  done
fi

echo -e "
  --------------------------------------------------------------------------
  ${BLUE}ℹ️  Container Information${NC}

    OS:              $(. /etc/os-release && echo "${PRETTY_NAME}")
    Service:         MariaDB
    Environment:     $ENVIRONMENT

    MariaDB version: $(mariadb --version | head -n 1)

    Docker user:     docker
    Docker uid:      $CURRENT_UID
    Docker gid:      $CURRENT_GID

  --------------------------------------------------------------------------
  ${GREEN}🚀  Starting MariaDB ...${NC}

  --------------------------------------------------------------------------
  ${GREEN}🔥  Streaming logs ...${NC}
"

# Start command in the foreground
exec su-exec docker "$@"
