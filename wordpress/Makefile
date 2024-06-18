# Makefile

# Include the .env file and setup-env.sh script
-include .env
export

# Docker containers
CONTAINER_NGINX=docker compose exec -T nginx sh -c
CONTAINER_PHP=docker compose exec -T php-fpm sh -c
CONTAINER_MARIADB=docker compose exec -T mariadb sh -c
CONTAINER_CLAMAV=docker compose exec -T clamav sh -c

# Define the default target
.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "\nAvailable commands:\n"
	@echo "  make env                    Creates the default .env file and populates it with your local environment variables"
	@echo "  make stop                   Stops all running containers"
	@echo "  make setup                  Builds the containers and all project files for production, and initializes the database"
	@echo "  make initialize-db          Initializes the database with the default data (production only)"
	@echo "  make production             Builds the containers and all project files for production, and runs migrations"
	@echo "  make staging                Builds the containers and all project files for staging, and initializes the database"
		@echo "  make dev                    Builds the containers and all project files for development and starts watching for changes"
	@echo "  make test                   Builds the containers and all project files for staging, and runs the linters and tests"
	@echo "  make fix                    Fixes the code style issues that can be fixed automatically"
	@echo "  make composer               Installs the composer dependencies"
	@echo "  make npm                    Installs the node dependencies"
	@echo "  make reset                  Resets the project by stopping and removing all containers, removing all volumes, and setting up the project again"
	@echo "  make clean                  Deletes all volumes, networks, and images related to the project and danglining images"
	@echo "  make ssh-CONTANER_NAME      SSH into the specified container"
	@echo "  make rebuild-CONTAINER_NAME Rebuild the specified container\n\n"

# Temporary fix for the issue with the optipng-bin package
.PHONY: link_optipng
link_optipng:
	$(CONTAINER_PHP) 'cp -f /usr/bin/optipng /var/www/node_modules/optipng-bin/vendor/optipng'

.PHONY: check-env
check-env:
	@if [ ! -f .env ]; then \
		echo "\n\n Error: .env file not found! Please run 'make env'.\n\n"; \
		exit 1; \
	fi

.PHONY: env
env:
	cp .env.example .env
	.docker/setup-env.sh

.PHONY: stop
stop:
	docker compose -f docker-compose.yml down

.PHONY: setup
setup:
	@$(MAKE) check-env
	docker network create proxy || true
	docker compose up --build -d
	$(CONTAINER_PHP) 'yarn node:install'
	$(CONTAINER_PHP) 'yarn composer:install'
	$(CONTAINER_PHP) 'yarn wp:clean --no-confirm'
	$(CONTAINER_PHP) 'yarn wp:db:init --no-confirm'
	$(CONTAINER_PHP) 'yarn wp:db:migrate --no-confirm'
	$(CONTAINER_PHP) 'yarn wp:uploads:symlink --no-confirm'
	make link_optipng
	$(CONTAINER_PHP) 'yarn webpack:wp:build'
	$(CONTAINER_PHP) 'php composer/vendor/interconnectit/search-replace-db/srdb.cli.php -h mariadb -n ${DB_DATABASE} -u ${DB_USERNAME} -p "${DB_PASSWORD}" -s "http://localhost" -r "https://${TRAEFIK_HOSTNAME}"'

.PHONY: initialize-db
initialize-db:
	@echo "Initializing default database..."
	@docker cp annotext-php-fpm:/var/www/wordpress/migrations/latest.sql.zip latest.sql.zip
	@docker cp latest.sql.zip annotext-mariadb:/tmp/latest.sql.zip
	@$(CONTAINER_MARIADB) 'unzip -p /tmp/latest.sql.zip | mysql -P $(DB_PORT) -u $(DB_USERNAME) -p$(DB_PASSWORD) $(DB_DATABASE)'
	@rm latest.sql.zip
	@echo "Database import completed."

.PHONY: production
production:
	@$(MAKE) check-env
	docker network create proxy || true
	docker compose -f docker-compose.production.yml up --build -d

.PHONY: staging
staging:
	@$(MAKE) check-env
	make production

.PHONY: dev
dev:
	@$(MAKE) check-env
	make setup
	$(CONTAINER_PHP) 'yarn webpack:wp:dev'

.PHONY: test
test:
	@$(MAKE) check-env
	make setup
	$(CONTAINER_PHP) 'yarn lint'

.PHONY: fix
fix:
	$(CONTAINER_PHP) 'yarn fix'

.PHONY: composer
composer:
	$(CONTAINER_PHP) 'composer install'

.PHONY: npm
npm:
	$(CONTAINER_PHP) 'npm install'

.PHONY: reset
reset:
	@$(MAKE) check-env
	docker compose -f docker-compose.yml down
	docker ps -a --filter "name=${COMPOSE_PROJECT_NAME}" -q | xargs docker rm -f
	make setup

.PHONY: clean
clean:
	@$(MAKE) check-env
	docker compose -f docker-compose.yml down
	docker ps -a --filter "name=${COMPOSE_PROJECT_NAME}" -q | xargs docker rm -f
	docker volume ls -q | grep '^${COMPOSE_PROJECT_NAME}' | xargs docker volume rm
	docker image prune -a -f

.PHONY: ssh-%
ssh-%:
	docker exec -it ${COMPOSE_PROJECT_NAME}-$* /bin/sh

.PHONY: rebuild-%
rebuild-%:
	docker compose up -d --no-deps --force-recreate --build $*
