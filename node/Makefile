# Makefile

# Include the .env file and setup-env.sh script
-include .env
export

# Ask for environment if not defined
ifndef ENVIRONMENT
export ENVIRONMENT := $(shell read -p "Enter environment (development|staging|production): " ENVIRONMENT; echo $$ENVIRONMENT)
endif

# Colors for output
RED:=\033[0;31m
GREEN:=\033[0;32m
BLUE:=\033[0;34m
NC:=\033[0m

# Emojis
EMOJI_CHECK:=✅
EMOJI_INFO:=ℹ️
EMOJI_WARNING:=🛑
EMOJI_WHALE:=🐳

# Docker containers
CONTAINER_NGINX=docker compose exec -T nginx sh -c
CONTAINER_NODE=docker compose exec -T node sh -c

# Define the default target
.DEFAULT_GOAL := help

.PHONY: help
help:
	# Start message
	@echo "	    _____"
	@echo "	 __|___  |__  _____   ____    ______  ______  ____  ____   _   _____    "
	@echo "	|   ___|    ||     | |    \  |   ___||   ___||    ||    \ | | /     \\ "
	@echo "	|   |  |    ||     \ |     \ |   ___||   ___||    ||     \| ||       | "
	@echo "	|______|  __||__|\__\|__|\__\|___|   |___|   |____||__/\____| \_____/  "
	@echo "	  |_____|    $(RED)Makefile for ${COMPOSE_PROJECT_NAME} $(NC)"
	@echo "	--------------------------------------------------------------------------"
	@echo "	$(BLUE)$(EMOJI_WHALE) Available commands$(NC)\n"

	@echo "	  make $(GREEN)env$(NC)                    Creates the default development '.env' file and populates it with your local environment variables"
	@echo "	  make $(GREEN)env-auth$(NC)               Creates the default development '.env' file and populates it with your local environment variables and creates a password for basic auth"
	@echo "	  make $(GREEN)start$(NC)                  Starts the specified container"
	@echo "	  make $(GREEN)stop$(NC)                   Stops all running containers"
	@echo "	  make $(GREEN)build$(NC)                  Builds the development containers and pushes them to the registry"
	@echo "	  make $(GREEN)setup$(NC)                  Builds the containers and all project files, and initializes the database"
	@echo "	  make $(GREEN)update$(NC)                 Pulls the latest images from the registry and restarts the containers"
	@echo "	  make $(GREEN)production$(NC)             Starts the production environment"
	@echo "	  make $(GREEN)staging$(NC)                Starts the staging environment"
	@echo "	  make $(GREEN)development|dev$(NC)        Starts the development environment"
	@echo "	  make $(GREEN)test$(NC)                   Runs tests"
	@echo "	  make $(GREEN)lint$(NC)                   Runs the linters"
	@echo "	  make $(GREEN)fix$(NC)                    Fixes the code issues that can be fixed automatically"
	@echo "	  make $(GREEN)composer$(NC)               Updates and installs the composer dependencies"
	@echo "	  make $(GREEN)yarn$(NC)                   Installs and updates the node dependencies"
	@echo "	  make $(GREEN)reset$(NC)                  Resets the project by stopping and removing all containers, removing all volumes, and setting up the project again"$(NC)
	@echo "	  make $(GREEN)ssh-CONTAINER_NAME$(NC)      SSH into the specified container"
	@echo "	  make $(GREEN)clean$(NC)                  Deletes all volumes, networks, and images related to the project and danglining images"
	@echo "	  make $(GREEN)clean-CONTAINER_NAME$(NC)   Deletes the specified container and its volumes"
	@echo "	  make $(GREEN)rebuild-CONTAINER_NAME$(NC) Rebuild the specified container"
	@echo "	  make $(GREEN)logs-CONTAINER_NAME$(NC)    Show the logs for the specified container\n"
	@echo "	  make $(GREEN)ps$(NC)                     Lists all containers specific to the project\n"

.PHONY: check-env
check-env:
	@if [ ! -f .env ]; then \
		@echo "\n 🛑 .env file not found! Please run 'make env'.\n"; \
		exit 1; \
	fi

.PHONY: env
env:
	@cp .env.${ENVIRONMENT} .env
	@chmod +x .docker/setup-env.sh
	@./.docker/setup-env.sh
	@ln -sf docker-compose.${ENVIRONMENT}.yml docker-compose.yml

.PHONY: env-auth
env-auth:
	@cp .env.${ENVIRONMENT} .env
	@chmod +x .docker/setup-env.sh
	@./.docker/setup-env.sh --create-password
	@ln -sf docker-compose.${ENVIRONMENT}.yml docker-compose.yml

.PHONY: start
start:
	@echo "\n  ℹ️  Starting all containers...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml up -d
	@echo "\n  ✅  All containers started.\n";

.PHONY: stop
stop:
	@echo "\n  ℹ️  Stopping all containers...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml stop

.PHONY: setup
setup:
	@echo "\n   ℹ️  Building all containers and running setup...\n";
	@$(MAKE) check-env
	@docker network create proxy &>/dev/null || true
	@docker compose -f docker-compose.${ENVIRONMENT}.yml up --build -d
	$(CONTAINER_NODE) 'yarn install'
	$(CONTAINER_NODE) 'yarn build'
	@echo "\n  ✅  All containers built and setup completed.\n";

.PHONY: build
build:
	@echo "\n   ℹ️  Building and pushing development containers...\n";
	@$(MAKE) check-env
	@$(MAKE) login
	@docker buildx build \
		--platform linux/arm64 \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg REVISION=$(shell git rev-parse --short HEAD) \
		--build-arg USER_ID=$(USER_ID) \
		--build-arg GROUP_ID=$(GROUP_ID) \
		--build-arg ENVIRONMENT=$(ENVIRONMENT) \
		--build-arg TRAEFIK_HOSTNAME=$(TRAEFIK_HOSTNAME) \
		--build-arg TRAEFIK_USERNAME=$(TRAEFIK_USERNAME) \
		--build-arg TRAEFIK_PASSWORD=$(TRAEFIK_PASSWORD) \
		--build-arg TRAEFIK_RESOLVER=$(TRAEFIK_RESOLVER) \
		--build-arg AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
		--build-arg AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
		--build-arg AWS_HOSTED_ZONE_ID=$(AWS_HOSTED_ZONE_ID) \
		--build-arg GH_PACKAGES_TOKEN=$(GH_PACKAGES_TOKEN) \
		--build-arg GH_PACKAGES_USERNAME=$(GH_PACKAGES_USERNAME) \
		--file .docker/node/Dockerfile \
		--tag $(DCR)/$(DCR_ORG)/$(DCR_REPO)-node:${DCR_TAG} \
		--cache-from type=registry,ref=$(DCR)/$(DCR_ORG)/$(DCR_REPO)-node:${DCR_TAG} \
		--cache-to type=inline \
		--push \
		.
	@docker buildx build \
		--platform linux/arm64 \
		--build-arg BUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg REVISION=$(shell git rev-parse --short HEAD) \
		--build-arg USER_ID=$(USER_ID) \
		--build-arg GROUP_ID=$(GROUP_ID) \
		--build-arg ENVIRONMENT=$(ENVIRONMENT) \
		--build-arg TRAEFIK_HOSTNAME=$(TRAEFIK_HOSTNAME) \
		--build-arg TRAEFIK_USERNAME=$(TRAEFIK_USERNAME) \
		--build-arg TRAEFIK_PASSWORD=$(TRAEFIK_PASSWORD) \
		--build-arg TRAEFIK_RESOLVER=$(TRAEFIK_RESOLVER) \
		--build-arg AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
		--build-arg AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
		--build-arg AWS_HOSTED_ZONE_ID=$(AWS_HOSTED_ZONE_ID) \
		--build-arg GH_PACKAGES_TOKEN=$(GH_PACKAGES_TOKEN) \
		--build-arg GH_PACKAGES_USERNAME=$(GH_PACKAGES_USERNAME) \
		--file .docker/nginx/Dockerfile \
		--tag $(DCR)/$(DCR_ORG)/$(DCR_REPO)-nginx:${DCR_TAG} \
		--cache-from type=registry,ref=$(DCR)/$(DCR_ORG)/$(DCR_REPO)-nginx:${DCR_TAG} \
		--cache-to type=inline \
		--push \
		.
	@echo "\n  ✅  Development containers built and pushed to $(DCR)/$(DCR_ORG)/$(DCR_REPO).\n";

.PHONY: login
login:
	@$(MAKE) check-env
ifeq ($(DCR), docker.io)
	@echo "\n  ℹ️  Logging in to DockerHub...\n"
	@echo ${DOCKERHUB_TOKEN} | docker login --username ${DOCKERHUB_USERNAME} --password-stdin
else ifeq ($(DCR), ghcr.io)
	@echo "\n  ℹ️  Logging in to GitHub Packages...\n"
	@echo ${GH_PACKAGES_TOKEN} | docker login ghcr.io --username ${GH_PACKAGES_USERNAME} --password-stdin
else
	@echo "\n  🛑  No defined Docker Container Registry (DCR) in the .env file...\n"
	@exit 1;
endif

.PHONY: update
update:
	@echo "  ℹ️  Starting containers update...\n";
	@$(MAKE) check-env
	@$(MAKE) login
	@docker network create proxy &>/dev/null || true
	@docker compose -f docker-compose.${ENVIRONMENT}.yml pull
	@docker compose -f docker-compose.${ENVIRONMENT}.yml up -d
	@docker image prune -f
	@docker logout
	@echo "\n  ✅  Containers update complete.\n";

.PHONY: production
production:
	@echo "\n  ℹ️  Starting production...\n";
	@$(MAKE) check-env
	@$(MAKE) update
	@echo "\n  ✅  Production started.\n";

.PHONY: staging
staging:
	@echo "\n  ℹ️  Starting staging...\n";
	@$(MAKE) check-env
	@$(MAKE) start
	@echo "\n  ✅  Staging started.\n";

.PHONY: dev
dev: development
.PHONY: development
development:
	@echo "\n  ℹ️  Starting development...\n";
	@$(MAKE) check-env
	@$(MAKE) update
	@$(MAKE) yarn
	@echo "\n  ✅  Starting development watch mode...\n";

.PHONY: test
test:
	@echo "\n  ℹ️  Starting tests...\n";
	@$(MAKE) check-env
	$(CONTAINER_NODE) 'yarn test'
	@echo "\n  ✅  Tests complete.\n";

.PHONY: lint
lint:
	@echo "\n  ℹ️  Starting tests...\n";
	@$(MAKE) check-env
	$(CONTAINER_NODE) 'yarn lint'
	@echo "\n  ✅  Lint complete.\n";

.PHONY: fix
fix:
	@echo "\n  ℹ️  Starting fixes...\n";
	@$(MAKE) check-env
	$(CONTAINER_NODE) 'yarn fix'
	@echo "\n  ✅  Fixes complete.\n";

.PHONY: yarn
yarn:
	@echo "\n  ℹ️  Installing & updating node modules...\n";
	@$(MAKE) check-env
	$(CONTAINER_NODE) 'yarn install'
	@echo "\n  ✅  Node modules install & update complete.\n";

.PHONY: ssh-%
ssh-%:
	@echo "\n  ℹ️  SSH into $*...\n";
	@$(MAKE) check-env
	@docker exec -it ${COMPOSE_PROJECT_NAME}-$* /bin/sh

.PHONY: stop-%
stop-%:
	@echo "\n  ℹ️  Stopping $*...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml stop $*
	@echo "\n  ✅  $* stopped.\n";

.PHONY: start-%
start-%:
	@echo "\n  ℹ️  Starting $*...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml up -d $*
	@echo "\n  ✅  $* started.\n";

.PHONY: clean
clean:
	@echo "\n  ℹ️  Starting cleaning all containers...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml down
	@docker ps -a --filter "name=${COMPOSE_PROJECT_NAME}-" -q | xargs docker rm -f &>/dev/null || true
	@docker volume ls -q | grep "^${COMPOSE_PROJECT_NAME}-" | xargs docker volume rm &>/dev/null || true
	@docker image prune -a -f
	@docker network prune -f
	@echo "\n  ✅  All containers cleaning complete.\n";

.PHONY: clean-%
clean-%:
	@echo "\n  ℹ️  Starting cleaning $*...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml stop $*
	@docker compose -f docker-compose.${ENVIRONMENT}.yml rm -f ${COMPOSE_PROJECT_NAME}-$*
	@docker volume prune -f
	@docker image prune -a -f
	@echo "\n  ✅  Cleaning $* complete.\n";


.PHONY: rebuild-%
rebuild-%:
	@echo "\n  ℹ️  Rebuilding $*...\n";
	@$(MAKE) check-env
	@docker compose -f docker-compose.${ENVIRONMENT}.yml up -d --no-deps --force-recreate --build $*
	@echo "\n  ✅  $* rebuid complete.\n";

.PHONY: logs-%
logs-%:
	@echo "\n  ℹ️  Showing logs for $*.\n";
	@$(MAKE) check-env
	@docker logs ${COMPOSE_PROJECT_NAME}-$*

.PHONY: ps
ps:
	@echo "\n  ℹ️  Listing all containers for project $(COMPOSE_PROJECT_NAME)...\n";
	@docker ps -a --filter "name=$(COMPOSE_PROJECT_NAME)-" --format "table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}\t{{.Status}}\t{{.Ports}}\t{{.Names}}"
