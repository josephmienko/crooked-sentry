FROM node:18-alpine

# Install WireGuard tools for key generation
RUN apk add --no-cache wireguard-tools

# Create app directory
WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install dependencies (use install since we may not have lockfile in all environments)
RUN npm install --omit=dev

# Copy app source
COPY server.js ./

# Create non-root user
RUN addgroup -g 1001 -S crooked && \
    adduser -S crooked -u 1001

# Create necessary directories
RUN mkdir -p /var/log/crooked-keys /opt/crooked-keys/data && \
    chown -R crooked:crooked /var/log/crooked-keys /opt/crooked-keys

USER crooked

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/api/crooked-keys/health || exit 1

CMD [ "node", "server.js" ]