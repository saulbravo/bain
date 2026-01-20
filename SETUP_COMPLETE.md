# ✅ Bolls Bible Setup Complete!

## What's Been Done

✅ **Repository cloned** - Full copy from https://github.com/Bolls-Bible/bain  
✅ **Tools installed** - docker-compose, mkcert (in ~/.local/bin)  
✅ **SSL certificates generated** - For bolls.local  
✅ **Docker images built** - Django, Imba, Nginx, and base images  
✅ **Containers started** - All services are running  
✅ **Database migrations** - All Django migrations applied  
✅ **Database restored** - **ALL translations and data loaded** (913MB backup)

## Current Status

### Running Containers:
- **database** - PostgreSQL with all Bible data
- **django** - Backend API (port 8000)
- **imba** - Frontend (port 3000)
- **nginx** - Web server

### Access Points:
- **Main Website**: http://localhost:8080
- **Django API**: http://localhost:8080/get-chapter/YLT/1/1/
- **Admin Panel**: http://localhost:8080/admin/

## Remaining Steps (Optional)

### 1. Add bolls.local to /etc/hosts (for full domain access)
```bash
echo "127.0.0.1 bolls.local" | sudo tee -a /etc/hosts
```

### 2. Configure port 80 (if you want to use port 80)
```bash
sudo sysctl net.ipv4.ip_unprivileged_port_start=80
```

### 3. Create Django Superuser (for admin access)
```bash
podman exec -it django python manage.py createsuperuser
```

### 4. Install mkcert CA (to avoid browser certificate warnings)
```bash
sudo mkcert -install
```

## What's Included

The database restore included:
- ✅ **All Bible translations** (141+ translations)
- ✅ **All books, chapters, and verses**
- ✅ **Commentaries and cross-references**
- ✅ **Dictionaries**
- ✅ **All site data**

## Useful Commands

### View container status
```bash
podman ps
```

### View logs
```bash
podman logs -f django    # Django logs
podman logs -f imba       # Frontend logs
podman logs -f database   # Database logs
```

### Stop containers
```bash
podman stop django imba nginx database
```

### Start containers (if stopped)
```bash
podman start database django imba nginx
```

### Restart a container
```bash
podman restart django
```

### Access Django shell
```bash
podman exec -it django python manage.py shell
```

### Access database
```bash
podman exec -it database psql -U postgres_user -d postgres_db
```

## Testing the Application

1. **Test Django API**:
   ```bash
   curl http://localhost:8000/get-text/YLT/1/1/
   ```

2. **Open in browser**:
   - Frontend: http://localhost:3000
   - API: http://localhost:8000

## Project Structure

```
Bible/
├── django/              # Django backend
│   ├── bolls/          # Main app
│   └── manage.py
├── imba/               # Frontend
├── sql/                # Database scripts
│   └── restore.sql     # Full database backup (913MB)
├── docker-compose.yml  # Container configuration
└── start-containers.sh # Container startup script
```

## Notes

- **Port 80**: Traefik couldn't bind to port 80 without sudo, but services are accessible on their direct ports
- **Certificates**: SSL certificates are generated but CA isn't installed (browser will show warning)
- **All data included**: The database restore contains everything - no need to download translations separately
- **Custom changes**: You can now make your modifications to the codebase

## Next Steps

1. Make your custom changes to the codebase
2. Test locally at http://localhost:3000 or http://localhost:8000
3. All translations and data are ready to use!

## Troubleshooting

### Containers not running?
```bash
podman ps -a  # Check all containers
podman start <container-name>
```

### Database connection issues?
```bash
podman logs database
podman exec database pg_isready -U postgres_user
```

### Django errors?
```bash
podman logs django
podman exec django python manage.py check
```

---

**Setup completed successfully!** 🎉

All translations and data from the Bolls Bible project are now available locally.

