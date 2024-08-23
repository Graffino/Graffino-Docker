# Get global arguments
ARG USERNAME=docker
ARG GROUPNAME=docker
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG ENVIRONMENT
ARG BUILD_DATE
ARG REVISION

# Get nginx image
FROM nginx:stable-alpine AS main

ARG BUILD_DATE
ARG REVISION

# Labels
LABEL maintainer="Graffino Software <team@graffino.com>"

# OCI Labels
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.created=${REVISION}
LABEL org.opencontainers.image.title="Nginx Image"
LABEL org.opencontainers.image.vendor="Graffino Software <team@graffino.com>"
LABEL org.opencontainers.image.description="Project Name - Nginx Docker image"
LABEL org.opencontainers.image.source="https://github.com/Graffino/Project-Name"

# Set local arguments
ARG USERNAME
ARG GROUPNAME
ARG USER_ID
ARG GROUP_ID
ARG ENVIRONMENT

# Set environment variables
ENV USERNAME=${USERNAME:-docker}
ENV GROUPNAME=${GROUPNAME:-docker}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}
ENV ENVIRONMENT=${ENVIRONMENT:-production}

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
  # Install utilities
  apk --no-cache add --virtual .production-deps \
    mc \
    tini \
    shadow \
    su-exec
EOF

# Prepare Nginx configuration
COPY .docker/nginx/conf.d/${ENVIRONMENT}.conf.template /etc/nginx/templates/default.conf.template

RUN <<EOF
  # Remove user directive from Nginx configuration
  sed -i '/^user\s*nginx\s*;/d' /etc/nginx/nginx.conf
  # Create necessary folders & set permissions
  mkdir -p /var/www/ /var/log/nginx/ /etc/nginx/ /var/cache/nginx/ /var/run/
  chown -R ${USER_ID}:${GROUP_ID} /var/www/ /var/log/nginx/ /etc/nginx/ /var/cache/nginx/ /var/run/ /etc/nginx/templates/
  # Set temp folder permissions
  chown -R ${USER_ID}:${GROUP_ID} /tmp
  chmod -R 0777 /tmp
EOF

# Copy entrypoint script
COPY .docker/nginx/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check to ensure Nginx is running
HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=5s \
  CMD sh -c "curl --fail http://127.0.0.1:80 || exit 1"

# Expose HTTP port
EXPOSE 80

# Set working directory
WORKDIR /var/www/

# Define volumes
VOLUME ["/var/www"]

# Entry point
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

# Command
CMD ["nginx", "-g", "daemon off;"]
