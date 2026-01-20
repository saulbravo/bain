# Quick Start Guide - Bolls Bible Local Setup

## Current Status

✅ Repository cloned successfully
✅ `.env.dev` file created
✅ Docker network 'web' created
⚠️  Some steps require sudo access or manual intervention

## Required Tools Installation

You need to install these tools (requires sudo):

```bash
sudo dnf install -y make docker-compose
```

OR if you prefer podman-compose:

```bash
sudo dnf install -y make podman-compose
```

## Manual Steps Required

### 1. Add bolls.local to /etc/hosts

```bash
echo "127.0.0.1 bolls.local" | sudo tee -a /etc/hosts
```

### 2. Configure port 80 (Linux only)

```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

To make permanent, add to `/etc/sysctl.conf`:
```
net.ipv4.ip_unprivileged_port_start=80
```

## Automated Setup

Once the tools are installed, run:

```bash
./setup.sh
```

This will:
- Check for required tools
- Create network (already done ✅)
- Install mkcert and generate certificates
- Build Docker images
- Guide you through remaining steps

## Manual Setup (Alternative)

If you prefer to run commands manually:

```bash
# 1. Install mkcert (if not already installed)
sudo dnf install -y mkcert nss-tools
mkcert -install
./mkcert/mkcert-certs.sh

# 2. Build images
make build
# OR: docker-compose build
# OR: podman-compose build

# 3. Start containers
make up
# OR: docker-compose up -d
# OR: podman-compose up -d

# 4. Run migrations
make migrate
# OR: docker-compose exec django python manage.py migrate

# 5. Create superuser
make createsuperuser
# OR: docker-compose exec django python manage.py createsuperuser

# 6. Restore database (downloads all translations)
make restore-db
```

## What Gets Restored

The `make restore-db` command will:
- Download a complete database backup (~hundreds of MB)
- Restore all Bible translations
- Restore all books, verses, and chapters
- Restore commentaries and cross-references
- Restore dictionaries
- Set up PostgreSQL extensions (unaccent, pg_trgm)

## Access the Application

After setup, access at:
- **URL**: http://localhost:8080
- **Admin Panel**: http://localhost:8080/admin/ (use superuser credentials)

## Troubleshooting

### If make is not found
Install it: `sudo dnf install -y make`

### If docker-compose is not found
Install it: `sudo dnf install -y docker-compose`

### If containers won't start
Check logs: `docker-compose logs` or `podman-compose logs`

### If port 80 is in use
You may need to stop other services or modify `docker-compose.yml` to use a different port.

## Project Information

- **Repository**: https://github.com/Bolls-Bible/bain
- **License**: GPL-3.0
- **Backend**: Django (Python)
- **Frontend**: Imba
- **Database**: PostgreSQL
- **Web Server**: Nginx + Traefik

## Next Steps After Setup

1. Make your custom changes to the codebase
2. Test locally at https://bolls.local
3. All translations and data are included in the restored database

