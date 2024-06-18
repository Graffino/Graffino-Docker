#!/bin/sh

# Check the environment and execute commands accordingly
case "${ENVIRONMENT:-}" in
    production)
        echo "Running in production mode"
        sudo chown docker:docker /var/www/
        cp -r /home/docker/dist-wp /var/www/
        cp -r /home/docker/composer /var/www/
        cp -r /home/docker/wordpress /var/www/
        rm -rf /var/www/node_modules
        rm -rf /var/www/html
        rm -rf /var/www/.env
    ;;
    staging)
        echo "Running in staging mode"
        sudo chown docker:docker /var/www/
        cp -r /home/docker/dist-wp /var/www/
        cp -r /home/docker/wordpress/migrations/* /var/www/wordpress/migrations/
        rm -rf /var/www/html
        rm -rf /var/www/.env
    ;;
    *)
        echo "Running in development mode, not updating volume"
    ;;
esac

# Start crond
crond

# Start php-fpm
php-fpm

