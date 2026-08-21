# TrueNAS Scale — Bolls Bible (single container)

Deploy Bolls Bible as one Docker image: PostgreSQL, Django, Imba, and Nginx run together inside a single container.

## Docker Hub image

`docker.io/maxivious/bolls:v4.2.2`

Published from this repo via `make build-all-in-one` and `make publish-all-in-one`.

## TrueNAS Scale setup

1. Open **Apps → Discover Apps → Custom App**.
2. **Application name:** `bolls` (or any name you prefer).
3. **Container image:**
   - Repository: `maxivious/bolls`
   - Tag: `v4.2.2`
4. Leave **Entrypoint**, **CMD**, and **Args** empty (use image defaults).
5. **Port forwarding:**

   | Container port | Node port |
   |----------------|-----------|
   | `80`           | `9080` or higher |

   TrueNAS requires node ports **≥ 9000**.

6. **Storage** — add a host path volume:

   | Host path | Mount path |
   |-----------|------------|
   | e.g. `/mnt/pool/apps/bolls` | `/var/lib/postgresql/data` |

   Keep **Read Only** disabled. PostgreSQL must be able to write to this path.

7. **Environment variables:**

   | Variable | Example | Notes |
   |----------|---------|-------|
   | `POSTGRES_USER` | `bolls` | Database user |
   | `POSTGRES_PASSWORD` | *(secure password)* | Change from default |
   | `POSTGRES_DB` | `bolls` | Database name |
   | `SECRET_KEY` | *(random string)* | Django secret — change from default |
   | `DJANGO_ALLOWED_HOSTS` | `bolls.familybravo.com 192.168.1.15` | Your domain and/or LAN IP (not `*` if using HTTPS login) |
   | `DJANGO_USE_HTTPS` | `1` | **Required for Cloudflare/HTTPS** — sets secure CSRF/session cookies |
   | `DJANGO_CSRF_TRUSTED_ORIGINS` | `https://bolls.familybravo.com` | Optional if `DJANGO_ALLOWED_HOSTS` includes your domain |
   | `AUTO_RESTORE_DB` | `1` | **First run only** — downloads verse backup |

8. Deploy and open `http://<truenas-ip>:9080/` (or whatever node port you chose).

### After first successful start

1. Edit the app and set `AUTO_RESTORE_DB` to `0` (or remove it) so the backup is not re-imported on every restart.
2. Optional: enable **WebUI Portal** in TrueNAS pointed at your node port.

### First run timing

On a fresh install the database schema is created automatically, but **Bible verse text is not bundled in the image**. With `AUTO_RESTORE_DB=1`, the container downloads and imports a public backup (~2 GB). This can take **10–30 minutes**. Monitor progress in the app/workload logs.

Alternatively, import your own PostgreSQL dump into the mounted data directory before or after the first start.

## Local test

```bash
podman build -f docker/all-in-one/Dockerfile -t maxivious/bolls:v3.1 .
podman run --rm -p 8080:80 \
  -v bolls-pgdata:/var/lib/postgresql/data \
  -e AUTO_RESTORE_DB=1 \
  maxivious/bolls:v3.1
```

Then open http://localhost:8080/

## Build and publish

```bash
make build-all-in-one
podman login docker.io -u maxivious
make publish-all-in-one
```

Or manually:

```bash
podman build -f docker/all-in-one/Dockerfile -t docker.io/maxivious/bolls:v3.1 .
podman push docker.io/maxivious/bolls:v3.1
```

Tag a new release by changing the version in the Makefile `build-all-in-one` / `publish-all-in-one` targets and in this README.

## What's inside

- **Nginx** on port 80 (public entry point)
- **Imba** frontend on 127.0.0.1:3000
- **Django/Gunicorn** API on 127.0.0.1:8000
- **PostgreSQL** on 127.0.0.1:5432 (data persisted via volume)
- **Adventist commentary** (`.cmtx`) bundled in the image

## Development vs production

| Setup | Use case |
|-------|----------|
| `docker compose up` (see [docs/LOCAL_DEV_WITH_DOCKER_COMPOSER.md](../../docs/LOCAL_DEV_WITH_DOCKER_COMPOSER.md)) | Local development |
| `maxivious/bolls:v4.2.2` all-in-one image | TrueNAS Scale, single-container production |
