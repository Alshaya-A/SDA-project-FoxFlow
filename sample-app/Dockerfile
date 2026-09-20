# Use the official Node 24 slim image — small and matches package.json engines
FROM node:24-slim

# Create app directory inside the container
# Remove npm and its bundled packages because the runtime only needs Node.js.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

WORKDIR /app

# Copy only what the app needs to run
COPY package.json ./
COPY server.js ./
COPY public ./public

# Run as the built-in non-root "node" user (security: never run as root)
USER node

# Document the port the app listens on
EXPOSE 3000

# Start the app
CMD ["node", "server.js"]
