# Bolls Bible Local Setup Guide

This guide will help you set up a complete local copy of the Bolls Bible application with all translations and data.

## Prerequisites

You need to install the following tools (requires sudo access):

1. **make** - Build automation tool
   ```bash
   sudo dnf install -y make
   ```

2. **docker-compose** - For orchestrating containers
   ```bash
   sudo dnf install -y docker-compose
   ```
   
   OR if you prefer podman-compose:
   ```bash
   sudo dnf install -y podman-compose
   ```

3. **mkcert** - Will be installed automatically by the setup script, but you can install it manually:
   ```bash
   sudo dnf install -y mkcert nss-tools
   ```

## Setup Steps

### Step 1: Add bolls.local to /etc/hosts

Add the following line to `/etc/hosts`:
```bash
echo "127.0.0.1 bolls.local" | sudo tee -a /etc/hosts
```

### Step 2: Configure system for port 80 (Linux only)

Allow non-root processes to bind to port 80:
```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

To make this permanent, add to `/etc/sysctl.conf`:
```
net.ipv4.ip_unprivileged_port_start=80
```

### Step 3: Run the setup commands

From the project root directory (`/home/maxivious/Documents/Bible`):

```bash
# 1. Create Docker network
make create-network

# 2. Install mkcert and generate SSL certificates
make mkcert-install

# 3. Build Docker images
make build

# 4. Start the containers
make up
```

**Note:** The `make up` command will start containers in the foreground. You may want to run it in a separate terminal or use `docker compose up -d` to run in the background.

### Step 4: Initialize the database

Once containers are running (in a new terminal):

```bash
# Run migrations
make migrate

# Create a superuser (interactive - you'll be prompted for credentials)
make createsuperuser
```

### Step 5: Restore database with all translations

This will download and restore all translations, commentaries, and other data:

```bash
make restore-db
```

This command will:
- Download the database backup from Google Cloud Storage
- Restore all translations, books, verses, commentaries, and dictionaries
- Set up PostgreSQL extensions (unaccent, pg_trgm)
- Restore indexes and sequences

### Step 6: Access the application

Open your browser and navigate to:
```
https://bolls.local
```

You may need to accept the self-signed certificate warning since we're using mkcert for local development.

## Alternative: Using Podman directly

If you prefer not to use make or docker-compose, you can run the commands directly:

```bash
# Create network
podman network create web

# Build images
podman compose build

# Start containers
podman compose up -d

# Run migrations
podman compose exec django python manage.py migrate

# Create superuser
podman compose exec django python manage.py createsuperuser

# Restore database (see Makefile for full command)
# This requires downloading the backup first
wget https://storage.googleapis.com/resurrecting-cat.appspot.com/backup.sql -O sql/restore.sql
podman cp sql/restore.sql database:/restore.sql
podman compose exec database psql -U postgres_user -d postgres_db -f ./restore.sql
# ... (see Makefile for complete restore-db command)
```

## Troubleshooting

### Port 80 already in use
If port 80 is already in use, you can modify `docker-compose.yml` to use a different port, or stop the service using port 80.

### Certificate issues
If you have certificate issues, regenerate them:
```bash
make certs-generate
```

### Database connection errors
Make sure the database container is running:
```bash
docker compose ps
# or
podman compose ps
```

### View logs
```bash
docker compose logs -f
# or
podman compose logs -f
```

## Project Structure

- `django/` - Django backend (Python)
- `imba/` - Frontend (Imba framework)
- `sql/` - Database scripts and backups
- `nginx_dev/` - Nginx configuration for development
- `traefik/` - Reverse proxy configuration
- `docker-compose.yml` - Development container orchestration

## Next Steps

After setup is complete, you can:
- Make your custom changes to the codebase
- Access the admin panel at `https://bolls.local/admin/` (use the superuser credentials you created)
- All translations and data should be available in the application

