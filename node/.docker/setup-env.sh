#!/bin/bash

set -eu

# Constants
ENV_FILE=".env"
MUTATED_GROUP_ID=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Source the .env file to load environment variables
if [ -f "$ENV_FILE" ]; then
  set -o allexport
  # shellcheck source=./
  source "$ENV_FILE"
  set +o allexport
else
  echo -e "    ${RED}🛑  '$ENV_FILE' file not found! Run 'make env' to create it.${NC}\n"
  exit 1
fi

# Set a default value for COMPOSE_PROJECT_NAME if not set in .env
: "${COMPOSE_PROJECT_NAME:=}"

# Provide a default value for OSTYPE if it is not set
: "${OSTYPE:=unknown}"

# Alternatively, determine the operating system if OSTYPE is not set
if [ -z "${OSTYPE}" ]; then
  case "$(uname)" in
  Linux*) OSTYPE="linux-gnu" ;;
  Darwin*) OSTYPE="darwin" ;;
  CYGWIN*) OSTYPE="cygwin" ;;
  MINGW*) OSTYPE="msys" ;;
  *) OSTYPE="unknown" ;;
  esac
fi

# Start message
echo -e "
     _____
  __|___  |__  _____   ____    ______  ______  ____  ____   _   _____
 |   ___|    ||     | |    \  |   ___||   ___||    ||    \ | | /     \\
 |   |  |    ||     \ |     \ |   ___||   ___||    ||     \| ||       |
 |______|  __||__|\__\|__|\__\|___|   |___|   |____||__/\____| \_____/
    |_____|   ${RED}'$ENV_FILE' file setup for ${COMPOSE_PROJECT_NAME} ${NC}

  --------------------------------------------------------------------------
  ${BLUE}🤝 Prerequisites Check${NC}
"

# Function to check if a command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Check dependencies for password hashing
check_hashing_dependencies() {
  if command_exists htpasswd; then
    HASH_CMD="htpasswd"
  elif command_exists openssl; then
    HASH_CMD="openssl"
  else
    echo -e "    ${RED}🛑  Neither 'htpasswd' nor 'openssl' could be found. Please install one of them.${NC}\n"
    exit 1
  fi
}

# Function to check other dependencies
check_dependencies() {
  if [ ! -f "$ENV_FILE" ]; then
    echo -e "    ${RED}🛑  '$ENV_FILE' file not found! Run 'make env' to create it.${NC}\n"
    exit 1
  fi
}

# Function to update or add a key-value pair in the .env file
update_env_file() {
  local key="$1"
  local value="$2"

  if grep -q "^${key}=" "$ENV_FILE"; then
    case "$OSTYPE" in
    "darwin"*)
      sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
      ;;
    *)
      sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
      ;;
    esac
  else
    echo "${key}=${value}" >>"$ENV_FILE"
  fi
}

# Function to generate htpasswd hash using htpasswd
generate_htpasswd() {
  local USERNAME="$1"
  local PASSWORD="$2"
  local HASH

  HASH=$(htpasswd -nbB "$USERNAME" "$PASSWORD" | cut -d ':' -f 2)
  echo "$HASH"
}

# Function to generate htpasswd hash using openssl
generate_openssl_hash() {
  local PASSWORD="$1"
  local SALT
  local HASH

  # Generate a random salt
  SALT=$(head -c 8 /dev/urandom | base64 | tr '+/' './' | cut -c1-8)

  # Create the MD5 hash
  HASH=$(openssl passwd -apr1 -salt "$SALT" "$PASSWORD")

  echo "$HASH"
}

# Function to prompt for username and password and generate hash
create_password() {
  echo -e "
  --------------------------------------------------------------------------
  ${BLUE}🤝  Generate basic authentication information${NC}
  "
  read -rp "    Enter username: " GENERATED_USERNAME
  read -rsp "    Enter password: " PASSWORD
  echo

  # Generate the htpasswd hash based on available command
  if [ "$HASH_CMD" == "htpasswd" ]; then
    HASH=$(generate_htpasswd "$GENERATED_USERNAME" "$PASSWORD")
  else
    HASH=$(generate_openssl_hash "$PASSWORD")
  fi

  # Escape the $ characters for Docker
  HASHED_PASSWORD=$(printf '%s\n' "$HASH" | sed 's/\$/\$\$/g')
}

# Main script logic
main() {
  # Get the current UID and GID of the system user
  USER_ID=$(id -u)
  GROUP_ID=$(id -g)

  check_dependencies
  check_hashing_dependencies

  echo -e "    ${GREEN}✅  Dependencies are met.${NC}"

  # Prevent issues with GID conflict (macOS)
  if [ "$GROUP_ID" -lt 501 ]; then
    MUTATED_GROUP_ID=true
    GROUP_ID=$USER_ID
  fi

  # Initialize variables for password generation
  GENERATED_USERNAME=""
  HASHED_PASSWORD=""
  CREATE_PASSWORD=false

  # Check for arguments
  while [ "$#" -gt 0 ]; do
    case $1 in
    --create-password)
      CREATE_PASSWORD=true
      ;;
    esac
    shift
  done

  # If not skipping password, create a new username and hashed password
  if [ "$CREATE_PASSWORD" = true ]; then
    create_password

    if [ -z "$GENERATED_USERNAME" ] || [ -z "$HASHED_PASSWORD" ]; then
      echo -e "\n    ${RED}🛑  Failed to generate username and hashed password.${NC}\n"
      exit 1
    fi

    update_env_file "TRAEFIK_USERNAME" "$GENERATED_USERNAME"
    update_env_file "TRAEFIK_PASSWORD" "$HASHED_PASSWORD"
  fi

  # Update USER_ID and GROUP_ID in the .env file
  update_env_file "USER_ID" "$USER_ID"
  update_env_file "GROUP_ID" "$GROUP_ID"

  # Echo result
  echo -e "
  --------------------------------------------------------------------------
  ${BLUE}ℹ️  Environment Variables${NC}

    ✅  'USER_ID' has been set to '${USER_ID}' in the '$ENV_FILE' file."
  if [ "$MUTATED_GROUP_ID" = true ]; then
    echo -e "    ℹ️   'GROUP_ID' was mutated to 'USER_ID' to prevent conflicts because it had a lower value than '501'."
  fi
  echo -e "    ✅  'GROUP_ID' has been set to '${GROUP_ID}' in the '$ENV_FILE' file.\n"

  if [ "$CREATE_PASSWORD" = true ]; then
    echo -e "    ✅  'TRAEFIK_USERNAME' has been set to '${GENERATED_USERNAME}'."
    echo -e "    ✅  'TRAEFIK_PASSWORD' has been set to '${PASSWORD}' (${HASHED_PASSWORD}).\n"
  fi
}

# Execute main function
main "$@"
