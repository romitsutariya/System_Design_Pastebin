# Stage 1: build the React app with Vite
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy the rest of the source code
COPY . .

# Build the app (Vite will read .env at build time)
RUN npm run build

# Stage 2: serve with NGINX
FROM nginx:1.27-alpine

# Remove default nginx static assets and copy our build output
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy a basic nginx config (enables gzip and SPA fallback)
# If not provided, default config will work too, but this is recommended.
# You can add an nginx.conf later if you need custom headers or caching.

EXPOSE 80

# Start NGINX
CMD ["nginx", "-g", "daemon off;"]
