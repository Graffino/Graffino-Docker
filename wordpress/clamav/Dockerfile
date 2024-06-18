FROM alpine:latest

# Set environment variables for user creation
ARG USERNAME=docker
ARG GROUPNAME=${USERNAME}
ARG USER_ID=${USER_ID:-1000}
ARG GROUP_ID=${USER_ID:-1000}

# Create a non-root user with USER_ID and GROUP_ID from build arguments
RUN apk --no-cache add sudo shadow && \
  addgroup -g ${GROUP_ID} ${GROUPNAME} && \
  adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME} && \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install ClamAV and set permissions
RUN apk --no-cache add clamav && \
  mkdir -p /run/clamav && \
  chown -R ${USERNAME}:${GROUPNAME} /run/clamav/ /var/log/clamav/ /var/lib/clamav/

# Copy custom ClamAV configuration files
COPY .docker/clamav/clamd/clamd.conf /etc/clamav/
COPY .docker/clamav/clamd/freshclam.conf /etc/clamav/

# Install utilities
RUN apk --no-cache add vim mc

# Switch to non-root user
USER ${USERNAME}

# Define volumes for ClamAV
VOLUME ["/var/lib/clamav"]

# Expose the ClamAV port
EXPOSE 3310

# Health check to ensure ClamAV is running
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD clamdscan --ping 1 || exit 1

# Create a script to start both freshclamd and clamd
COPY .docker/clamav/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

# Start the script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD [""]
