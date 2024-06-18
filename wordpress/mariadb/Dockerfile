FROM alpine:latest

# Set environment variables for MariaDB
ARG USERNAME=docker
ARG GROUPNAME=${USERNAME}
ARG USER_ID=${USER_ID:-1000}
ARG GROUP_ID=${USER_ID:-1000}
ENV USERNAME=docker
ENV GROUPNAME=${USERNAME}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}

ARG DB_PORT=${DB_PORT:-3306}
ARG DB_DATABASE=${DB_DATABASE:-"docker"}
ARG DB_USERNAME=${DB_USERNAME:-"docker"}
ARG DB_PASSWORD=${DB_PASSWORD}
ARG DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-""}

# Create a non-root user with USER_ID and GID from build arguments
RUN apk --no-cache add sudo shadow \
  && addgroup -g ${GROUP_ID} ${GROUPNAME} \
  && adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME} \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install MariaDB and utilities
RUN apk update && apk --no-cache add mariadb mariadb-client mariadb-server-utils vim mc

# Copy the MariaDB configuration file
COPY .docker/mariadb/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf

# Create folders & set permissions
RUN mkdir -p /var/lib/mysql /run/mysqld \
  && chown -R ${USERNAME}:${GROUPNAME} /var/lib/mysql /etc/my.cnf.d/ /run/mysqld

# Initialize MariaDB
RUN mysql_install_db --user=${USERNAME} --ldata=/var/lib/mysql \
  && chown -R ${USERNAME}:${GROUPNAME} /var/lib/mysql/


# Switch to non-root user
USER ${USER_ID}:${GROUP_ID}

# Run initialization script as root
RUN mysqld & \
  sleep 5 && \
  sudo mysql -uroot -e "CREATE DATABASE IF NOT EXISTS ${DB_DATABASE}; \
  CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED BY '${DB_PASSWORD}'; \
  GRANT ALL PRIVILEGES ON ${DB_DATABASE}.* TO '${DB_USERNAME}'@'%'; \
  FLUSH PRIVILEGES; \
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';" && \
  mysqladmin shutdown

# Expose the MariaDB port
EXPOSE 3306

# Add a volume to store the MariaDB data
VOLUME ["/var/lib/mysql"]

# Health check to ensure MYSQL is running
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD mysqladmin ping -p${DB_PASSWORD} || exit 1

# Start MariaDB
CMD ["mysqld"]
