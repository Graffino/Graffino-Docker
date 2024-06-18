FROM nginx:stable-alpine

# Set environment variables for user creation
ARG USERNAME=docker
ARG GROUPNAME=${USERNAME}
ARG USER_ID=${USER_ID:-1000}
ARG GROUP_ID=${USER_ID:-1000}
ENV USERNAME=docker
ENV GROUPNAME=${USERNAME}
ENV USER_ID=${USER_ID:-1000}
ENV GROUP_ID=${USER_ID:-1000}

# Create a non-root user with USER_ID and GROUP_ID from build arguments
RUN apk --no-cache add sudo shadow && \
  addgroup -g ${GROUP_ID} ${GROUPNAME} && \
  adduser -D -u ${USER_ID} -G ${GROUPNAME} ${USERNAME} && \
  echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create necessary folders & set permissions
RUN mkdir -p /var/www/ /var/log/nginx/ /etc/nginx/ /var/cache/nginx/ /var/run/ && \
  chown -R ${USERNAME}:${GROUPNAME} /var/www/ /var/log/nginx/ /etc/nginx/ /var/cache/nginx/ /var/run/

# Prepare Nginx configuration
COPY .docker/nginx/conf.d/default.conf.template /etc/nginx/templates/default.conf.template

RUN chown -R ${USERNAME}:${GROUPNAME} /etc/nginx/templates/

# Install utilities
RUN apk --no-cache add vim mc curl

# Expose HTTP port
EXPOSE 80

# Switch to non-root user
USER ${USERNAME}

# Set working directory
WORKDIR /var/www/

# Health check to ensure Nginx is running
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD sh -c "curl --fail http://127.0.0.1:80 || exit 1"

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
