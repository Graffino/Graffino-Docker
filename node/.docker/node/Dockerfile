# Get global arguments
ARG USERNAME=docker
ARG GROUPNAME=docker
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG ENVIRONMENT
ARG BUILD_DATE
ARG REVISION

# Get Node image
FROM node:20-alpine AS main

ARG BUILD_DATE
ARG REVISION

# Labels
LABEL maintainer="Graffino Software <team@graffino.com>"

# OCI Labels
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.revision=${REVISION}
LABEL org.opencontainers.image.title="NodeJS Image"
LABEL org.opencontainers.image.vendor="Graffino Software <team@graffino.com>"
LABEL org.opencontainers.image.description="Graffino Docker - NodeJS Docker image"
LABEL org.opencontainers.image.source="https://github.com/Graffino/Graffino-Docker"

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
ENV ENVIRONMENT=${ENVIRONMENT:-development}

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
  # Install development dependencies & utilities
  apk --no-cache add --virtual .development-deps \
    tini \
    shadow \
    su-exec \
    curl \
    yarn \
    mc
EOF

# Set working directory
WORKDIR /var/www

# Copy package.json and yarn.lock for dependency installation
COPY package.json yarn.lock ./

# Install Node.js dependencies
RUN yarn install --frozen-lockfile --no-progress --no-optional && yarn cache clean

# Copy remaining project files
COPY . .

# Ensure permissions are set correctly
RUN chown -R ${USER_ID}:${GROUP_ID} /var/www

# Copy entrypoint script
COPY .docker/node/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check to ensure Node.js is running
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=5s \
  CMD curl --fail http://localhost:3000 || exit 1

# Expose the application port
EXPOSE 3000

# Define volumes
VOLUME ["/var/www"]

# Entry point
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

# Command
CMD ["yarn", "preview"]
