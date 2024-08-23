# Dockerfile

# Get global arguments
ARG USERNAME=docker
ARG GROUPNAME=docker
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG ENVIRONMENT
ARG BUILD_DATE
ARG REVISION

ARG DB_PORT=3306
ARG DB_DATABASE=docker
ARG DB_USERNAME=docker
ARG DB_PASSWORD=admin
ARG DB_ROOT_PASSWORD=admin

# Get alpine image
FROM alpine:3.20 AS main

ARG BUILD_DATE
ARG REVISION

# Labels
LABEL maintainer="Graffino Software <team@graffino.com>"

# OCI Labels
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.revision=${REVISION}
LABEL org.opencontainers.image.title="MariaDB Image"
LABEL org.opencontainers.image.vendor="Graffino Software <team@graffino.com>"
LABEL org.opencontainers.image.description="Project Name - MariaDB Docker image"
LABEL org.opencontainers.image.source="https://github.com/Graffino/Project-Name"


# Set local arguments
ARG USERNAME
ARG GROUPNAME
ARG USER_ID
ARG GROUP_ID
ARG ENVIRONMENT

ARG DB_DATABASE
ARG DB_USERNAME
ARG DB_PASSWORD
ARG DB_ROOT_PASSWORD

# Set environment variables
ENV USERNAME=${USERNAME:-docker}
ENV GROUPNAME=${GROUPNAME:-docker}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}
ENV ENVIRONMENT=${ENVIRONMENT:-production}

ENV DB_DATABASE=${DB_DATABASE:-docker}
ENV DB_USERNAME=${DB_USERNAME:-docker}
ENV DB_PASSWORD=${DB_PASSWORD:-admin}
ENV DB_ROOT_PASSWORD=${DB_PASSWORD:-admin}

# Install utilities
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
RUN <<EOF
  # Delete user and group with ID 1000 if they exist
  deluser --remove-home "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true
  delgroup "$(getent group 1000 | cut -d: -f1)" 2>/dev/null || true
  # Add user and group
  addgroup -g ${GROUP_ID} ${GROUPNAME}
  adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME}
  addgroup ${USERNAME} tty
  # Install MariaDB and utilities
  apk --no-cache add --virtual .production-deps \
    mariadb \
    mariadb-client \
    mariadb-server-utils \
    mc \
    tini \
    shadow \
    su-exec
EOF

# Copy the MariaDB configuration file
COPY .docker/mariadb/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf

RUN <<EOF
  # Create folders & set permissions
  mkdir -p /var/lib/mysql /run/mysqld
  chown -R ${USER_ID}:${GROUP_ID} /var/lib/mysql /etc/my.cnf.d/ /run/mysqld
  # Set temp folder permissions
  chown -R ${USER_ID}:${GROUP_ID} /tmp
  chmod -R 0777 /tmp
EOF

# Copy entrypoint script
COPY .docker/mariadb/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check to ensure MYSQL is running
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=10s \
  CMD mysqladmin ping -u${DB_USERNAME} -p${DB_PASSWORD} || exit 1

# Expose the MariaDB port
EXPOSE 3306

# Add a volume to store the MariaDB data
VOLUME ["/var/lib/mysql"]

# Entry point
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

# Command
CMD ["mysqld"]
