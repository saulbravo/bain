# Setup Status - Bolls Bible Local Copy

## ✅ Completed Steps

1. **Repository Cloned** - Full copy of https://github.com/Bolls-Bible/bain
2. **Environment File Created** - `.env.dev` file created (can be empty for dev)
3. **Docker Network Created** - Network 'web' is ready
4. **Scripts Prepared** - Setup scripts are executable and ready

## ⚠️  Requires Manual Steps (sudo access needed)

### 1. Install Required Tools

```bash
sudo dnf install -y make docker-compose mkcert nss-tools
```

### 2. Add bolls.local to /etc/hosts

```bash
echo "127.0.0.1 bolls.local" | sudo tee -a /etc/hosts
```

### 3. Configure Port 80 (Linux)

```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

To make permanent:
```bash
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee -a /etc/sysctl.conf
```

## 🚀 Next Steps (After Installing Tools)

### Option A: Use the Automated Setup Script

```bash
./setup.sh
```

### Option B: Use Make Commands

```bash
# Install mkcert and generate certificates
make mkcert-install

# Build Docker images
make build

# Start containers
make up
```

Then in a new terminal:

```bash
# Run migrations
make migrate

# Create superuser
make createsuperuser

# Restore database with all translations
make restore-db
```

### Option C: Manual Commands

```bash
# Generate certificates
./mkcert/mkcert-install.sh
./mkcert/mkcert-certs.sh

# Build and start
docker-compose build
docker-compose up -d

# Initialize database
docker-compose exec django python manage.py migrate
docker-compose exec django python manage.py createsuperuser

# Restore all translations and data
make restore-db
```

## 📦 What Will Be Restored

The `make restore-db` command downloads and restores:
- Complete database backup from Google Cloud Storage
- **All Bible translations** (141 translation files in `django/bolls/static/translations/`)
- All books, chapters, and verses
- Commentaries and cross-references
- Dictionaries
- PostgreSQL extensions (unaccent, pg_trgm)

## 🌐 Access the Application

After setup completes:
- **Main App**: https://bolls.local
- **Admin Panel**: https://bolls.local/admin/

## 📁 Project Structure

```
Bible/
├── django/              # Django backend
│   ├── bolls/          # Main app
│   │   └── static/
│   │       └── translations/  # 141 translation ZIP files
│   └── manage.py
├── imba/               # Frontend (Imba framework)
├── sql/                # Database scripts
├── docker-compose.yml  # Development setup
├── Makefile           # Build commands
└── setup.sh          # Automated setup script
```

## 🔍 Verify Installation

Check if everything is working:

```bash
# Check containers are running
docker-compose ps

# Check logs
docker-compose logs -f

# Test Django is responding
curl http://localhost:8000/get-text/YLT/1/1/
```

## 📝 Notes

- The project uses **Podman** by default (configured in Makefile)
- If you prefer Docker, you can modify the Makefile or use docker-compose directly
- All translations are included in the database backup - no need to download separately
- The restore process downloads ~hundreds of MB of data

## 🆘 Troubleshooting

### "make: command not found"
Install: `sudo dnf install -y make`

### "docker-compose: command not found"
Install: `sudo dnf install -y docker-compose`

### "mkcert: command not found"
Install: `sudo dnf install -y mkcert nss-tools`

### Port 80 already in use
Check what's using it: `sudo lsof -i :80`
Or modify `docker-compose.yml` to use a different port

### Certificate errors in browser
Regenerate: `make certs-generate` or `./mkcert/mkcert-certs.sh`

## ✨ Ready for Customization

Once the setup is complete and the application is running, you can:
- Make your custom changes to the codebase
- All translations and data are already included
- Test locally before deploying

