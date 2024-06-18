#!/bin/bash

# Define the variable name you want to update
ENV_VAR_NAME="USER_ID"

# Get the current user's UID
USER_UID=$(id -u)

# Check if the .env file exists
if [ ! -f .env ]; then
    echo ".env file not found!"
    exit 1
fi

# Check if the variable already exists in the .env file
if grep -q "^${ENV_VAR_NAME}=" .env; then
    # Update the existing variable with the UID
    sed -i.bak "s/^${ENV_VAR_NAME}=.*/${ENV_VAR_NAME}=${USER_UID}/" .env
else
    # Add the variable with the UID to the .env file
    echo "${ENV_VAR_NAME}=${USER_UID}" >> .env
fi

# Remove the backup file
rm -rf .env.bak

echo "${ENV_VAR_NAME} has been set to ${USER_UID} in the .env file."
