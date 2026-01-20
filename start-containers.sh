#!/bin/bash
# Script to start containers using podman directly

set -e

cd "$(dirname "$0")"

# Create internal network if it doesn't exist
podman network exists internal || podman network create internal

# Start database
echo "Starting database container..."
podman run -d \
  --name database \
  --network internal \
  -e POSTGRES_USER=postgres_user \
  -e POSTGRES_PASSWORD=postgres_password \
  -e POSTGRES_DB=postgres_db \
  -v bible_pgdata:/var/lib/postgresql/data \
  --restart on-failure \
  --security-opt label=disable \
  postgres:alpine

# Start Django
echo "Starting Django container..."
podman run -d \
  --name django \
  --network internal \
  --network web \
  -v "$(pwd)/django:/code" \
  -v "$(pwd)/imba:/imba" \
  -p 8000:8000 \
  -e DEBUG=1 \
  -e DJANGO_ALLOWED_HOSTS=bolls.local \
  -e SQL_ENGINE=django.db.backends.postgresql \
  -e SQL_DATABASE=postgres_db \
  -e SQL_USER=postgres_user \
  -e SQL_PASSWORD=postgres_password \
  -e SQL_HOST=database \
  -e SQL_PORT=5432 \
  -e DATABASE=postgres \
  --env-file .env.dev \
  --restart on-failure \
  --security-opt label=disable \
  localhost/bible-django:latest \
  python manage.py runserver 0:8000

# Start Imba
echo "Starting Imba container..."
podman run -d \
  --name imba \
  --network internal \
  --network web \
  -v "$(pwd)/imba:/app" \
  -p 3000:3000 \
  -e API_URL=http://django:8000 \
  --restart on-failure \
  --security-opt label=disable \
  localhost/bible-imba:latest \
  sh -c "npm i && npm run dev"

# Start Nginx
echo "Starting Nginx container..."
podman run -d \
  --name nginx \
  --network internal \
  -v "$(pwd)/django/bolls/static:/home/bolls/web/static:delegated" \
  -v "$(pwd)/imba:/imba:delegated" \
  -v "$(pwd)/nginx_dev/nginx.conf:/etc/nginx/conf.d/nginx.conf" \
  --restart on-failure \
  --security-opt label=disable \
  localhost/bible-nginx:latest

# Start Traefik
echo "Starting Traefik container..."
podman run -d \
  --name traefik \
  --network web \
  --network internal \
  -p 8080:80 \
  -p 8443:443 \
  -v "$(pwd)/traefik/letsencrypt:/letsencrypt" \
  -v /run/user/1000/podman/podman.sock:/var/run/docker.sock \
  -v "$(pwd)/traefik/config/static.yml:/etc/traefik/traefik.yml:ro" \
  -v "$(pwd)/traefik/config/dynamic.yml:/etc/traefik/dynamic.yml:ro" \
  -v "$(pwd)/traefik/certs:/etc/certs:ro" \
  --restart on-failure \
  --security-opt label=disable \
  traefik:latest \
  --api.insecure=true \
  --providers.docker=true \
  --providers.docker.exposedbydefault=false \
  --entrypoints.web.address=:80

echo ""
echo "All containers started!"
echo "Check status with: podman ps"
echo "View logs with: podman logs -f <container-name>"

