# Running with Docker

This guide explains how to build and run the Salesforce OAuth Demo application using Docker.

## Prerequisites

- Docker Desktop installed and running
- Salesforce Connected App configured (see [AUTH_SETUP.md](AUTH_SETUP.md))
- Your Salesforce credentials (Client ID and Secret)

---

## Quick Start

### 1. Build the Docker Image

From the project root directory:

```bash
docker build -t sf-oauth-demo .
```

This creates a Docker image named `sf-oauth-demo` based on Node.js 18 Alpine Linux.

**Build Output:**
```
[+] Building 45.2s (12/12) FINISHED
 => [internal] load build definition
 => => transferring dockerfile: 123B
 => [internal] load .dockerignore
 => [internal] load metadata for docker.io/library/node:18-alpine
 => [1/6] FROM docker.io/library/node:18-alpine
 => [2/6] WORKDIR /app
 => [3/6] COPY package*.json ./
 => [4/6] RUN npm ci --only=production
 => [5/6] COPY src/ ./src/
 => [6/6] COPY public/ ./public/
 => exporting to image
 => => naming to docker.io/library/sf-oauth-demo
```

---

## Running the Container

### Option 1: Using .env File (Recommended)

This is the easiest method - use your existing `.env` file:

```bash
docker run -p 3000:3000 --env-file .env sf-oauth-demo
```

**Advantages:**
- Simple one-line command
- Reuses your existing configuration
- Easy to manage credentials

### Option 2: Pass Environment Variables Directly

Pass each environment variable individually:

```bash
docker run -p 3000:3000 \
  -e SF_CLIENT_ID="3MVG9IHf89I1t8hrvswazsWedXWY0iqK20PSF..." \
  -e SF_CLIENT_SECRET="1234567890ABCDEF" \
  -e SF_CALLBACK_URL="http://localhost:3000/oauth/callback" \
  -e SF_LOGIN_URL="https://login.salesforce.com" \
  -e SESSION_SECRET="your_random_session_secret_here" \
  -e PORT="3000" \
  sf-oauth-demo
```

**Note:** Replace the values with your actual Salesforce credentials.

### Option 3: Run in Detached Mode (Background)

To run the container in the background:

```bash
docker run -d -p 3000:3000 --env-file .env --name sf-oauth sf-oauth-demo
```

**Parameters explained:**
- `-d` - Run in detached mode (background)
- `-p 3000:3000` - Map port 3000 from container to host
- `--env-file .env` - Load environment variables from .env file
- `--name sf-oauth` - Give the container a friendly name
- `sf-oauth-demo` - The image name

---

## Verify the Container is Running

### Check Running Containers

```bash
docker ps
```

**Expected output:**
```
CONTAINER ID   IMAGE           COMMAND                  CREATED          STATUS                    PORTS                    NAMES
a1b2c3d4e5f6   sf-oauth-demo   "docker-entrypoint.s…"   10 seconds ago   Up 9 seconds (healthy)    0.0.0.0:3000->3000/tcp   sf-oauth
```

### View Container Logs

```bash
# If running in background (detached mode)
docker logs -f sf-oauth

# Or by container ID
docker logs -f a1b2c3d4e5f6
```

**Expected logs:**
```
🔧 Configuration loaded from .env
   Client ID: ✓ Set
   Client Secret: ✓ Set
   Callback URL: http://localhost:3000/oauth/callback
🚀 Server running on port 3000
🌐 Open http://localhost:3000
```

### Test the Application

Open your browser to **http://localhost:3000**

You should see the login page. The OAuth flow works the same as when running locally with Node.js.

---

## Docker Container Management

### Stop the Container

```bash
# By name
docker stop sf-oauth

# By container ID
docker stop a1b2c3d4e5f6
```

### Start a Stopped Container

```bash
docker start sf-oauth
```

### Restart the Container

```bash
docker restart sf-oauth
```

### Remove the Container

```bash
# Stop and remove
docker stop sf-oauth && docker rm sf-oauth

# Force remove (if running)
docker rm -f sf-oauth
```

### View Container Details

```bash
docker inspect sf-oauth
```

### Execute Commands Inside Container

```bash
# Open a shell inside the running container
docker exec -it sf-oauth /bin/sh

# Run a specific command
docker exec sf-oauth node -v
```

---

## Image Management

### List Docker Images

```bash
docker images
```

**Output:**
```
REPOSITORY      TAG       IMAGE ID       CREATED          SIZE
sf-oauth-demo   latest    abc123def456   5 minutes ago    145MB
```

### Remove the Image

```bash
docker rmi sf-oauth-demo
```

**Note:** You must remove all containers using this image first.

### Rebuild the Image

After making code changes:

```bash
# Rebuild the image
docker build -t sf-oauth-demo .

# Stop old container
docker stop sf-oauth && docker rm sf-oauth

# Run new container
docker run -d -p 3000:3000 --env-file .env --name sf-oauth sf-oauth-demo
```

---

## Health Checks

The Docker container includes a built-in health check that runs every 30 seconds.

### View Health Status

```bash
docker ps
```

Look for the `STATUS` column - it will show:
- `(health: starting)` - Health check initializing
- `(healthy)` - Application is healthy
- `(unhealthy)` - Application failed health check

### Manual Health Check

```bash
curl http://localhost:3000/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-06T17:30:00.000Z"
}
```

---

## Troubleshooting

### Container Won't Start

**Check logs:**
```bash
docker logs sf-oauth
```

**Common issues:**
- Missing environment variables
- Port 3000 already in use
- Invalid Salesforce credentials

### Port Already in Use

If port 3000 is already in use:

```bash
# Use a different port (e.g., 3001)
docker run -p 3001:3000 --env-file .env sf-oauth-demo
```

**Important:** If you change the port, update your Salesforce Connected App callback URL to match!

### Environment Variables Not Loading

**Verify .env file exists:**
```bash
ls -la .env
```

**Test with explicit variables:**
```bash
docker run -p 3000:3000 \
  -e SF_CLIENT_ID="your_id" \
  -e SF_CLIENT_SECRET="your_secret" \
  -e SF_CALLBACK_URL="http://localhost:3000/oauth/callback" \
  -e SF_LOGIN_URL="https://login.salesforce.com" \
  -e SESSION_SECRET="your_secret" \
  sf-oauth-demo
```

### Container Exits Immediately

**Check for errors:**
```bash
docker logs sf-oauth
```

**Run in interactive mode to debug:**
```bash
docker run -it --rm -p 3000:3000 --env-file .env sf-oauth-demo
```

The `--rm` flag automatically removes the container when it stops.

---

## Docker Compose (Optional)

For easier container management, you can use Docker Compose.

### Create docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build: .
    image: sf-oauth-demo
    container_name: sf-oauth
    ports:
      - "3000:3000"
    env_file:
      - .env
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"]
      interval: 30s
      timeout: 3s
      start_period: 5s
      retries: 3
```

### Using Docker Compose

```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down

# Rebuild and restart
docker-compose up -d --build
```

---

## Production Considerations

### 1. Use Multi-Stage Builds

For production, consider using a multi-stage build to reduce image size:

```dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# Production stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/src ./src
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
```

### 2. Use Environment Variables (Not .env File)

In production, pass environment variables through your orchestration system (Kubernetes, ECS, etc.) instead of using a `.env` file.

### 3. Enable HTTPS

Update callback URLs to use `https://` instead of `http://`.

### 4. Resource Limits

Set CPU and memory limits:

```bash
docker run -d \
  --cpus="1.0" \
  --memory="512m" \
  -p 3000:3000 \
  --env-file .env \
  --name sf-oauth \
  sf-oauth-demo
```

### 5. Logging

Use a logging driver:

```bash
docker run -d \
  --log-driver=json-file \
  --log-opt max-size=10m \
  --log-opt max-file=3 \
  -p 3000:3000 \
  --env-file .env \
  --name sf-oauth \
  sf-oauth-demo
```

---

## Security Best Practices

1. **Never commit .env file** - Add to `.gitignore`
2. **Use secrets management** - In production, use Docker Secrets or cloud provider secrets
3. **Run as non-root** - The Dockerfile already does this
4. **Scan for vulnerabilities:**
   ```bash
   docker scan sf-oauth-demo
   ```
5. **Keep base image updated:**
   ```bash
   docker pull node:18-alpine
   docker build --no-cache -t sf-oauth-demo .
   ```

---

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)
- [Authentication Setup Guide](AUTH_SETUP.md)
- [Main README](../README.md)

---

**Need help?** Check the [troubleshooting section](#troubleshooting) or review the [main documentation](../README.md).
