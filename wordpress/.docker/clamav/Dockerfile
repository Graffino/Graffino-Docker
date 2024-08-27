# Get global arguments
ARG USERNAME=docker
ARG GROUPNAME=docker
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG ENVIRONMENT
ARG BUILD_DATE
ARG REVISION

# Get alpine image
FROM alpine:3.20 AS main

ARG BUILD_DATE
ARG REVISION

# Labels
LABEL maintainer="Graffino Software <team@graffino.com>"

# OCI Labels
LABEL org.opencontainers.image.created=${BUILD_DATE}
LABEL org.opencontainers.image.revision=${REVISION}
LABEL org.opencontainers.image.title="ClamAV Image"
LABEL org.opencontainers.image.vendor="Graffino Software <team@graffino.com>"
LABEL org.opencontainers.image.description="AnNoText - ClamAV Docker image"
LABEL org.opencontainers.image.source="https://github.com/Graffino/AnNoText"

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
  # Install ClamAV and set permissions
  apk --no-cache add --virtual .production-deps \
  clamav \
  mc \
  tini \
  shadow \
  su-exec
  # Create clamav folders & set permissions
  mkdir -p /run/clamav
  chown -R ${USER_ID}:${GROUP_ID} /run/clamav/ /var/log/clamav/ /var/lib/clamav/
  chmod -R 0777 /run/clamav/ /var/log/clamav/ /var/lib/clamav/
  # Set temp folder permissions
  chown -R ${USER_ID}:${GROUP_ID} /tmp
  chmod -R 0777 /tmp
EOF

# Copy custom ClamAV configuration files
COPY .docker/clamav/clamd/clamd.conf /etc/clamav/
COPY .docker/clamav/clamd/freshclam.conf /etc/clamav/

# Copy entrypoint script
COPY .docker/clamav/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Health check to ensure ClamAV is running
HEALTHCHECK --interval=10s --timeout=5s --retries=3 --start-period=10s \
  CMD clamdscan --ping 1 || exit 1

# Expose the ClamAV port
EXPOSE 3310

# Define volumes for ClamAV
VOLUME ["/var/lib/clamav"]

# Entry point
ENTRYPOINT ["/sbin/tini", "--", "entrypoint.sh"]

# Command
CMD ["clamd", "--foreground"]
