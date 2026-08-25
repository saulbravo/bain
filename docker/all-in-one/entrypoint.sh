#!/bin/bash
set -euo pipefail

export PGDATA="${PGDATA:-/var/lib/postgresql/data}"
export POSTGRES_USER="${POSTGRES_USER:-bolls}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-bolls}"
export POSTGRES_DB="${POSTGRES_DB:-bolls}"
export DATABASE=postgres
export SQL_ENGINE="${SQL_ENGINE:-django.db.backends.postgresql}"
export SQL_HOST=127.0.0.1
export SQL_PORT=5432
export SQL_USER="$POSTGRES_USER"
export SQL_PASSWORD="$POSTGRES_PASSWORD"
export SQL_DATABASE="$POSTGRES_DB"
export DEBUG="${DEBUG:-0}"
export DJANGO_ALLOWED_HOSTS="${DJANGO_ALLOWED_HOSTS:-*}"

PG_BIN="$(pg_config --bindir)"
export PATH="$PG_BIN:$PATH"

mkdir -p "$PGDATA" /var/log/supervisor
chown -R postgres:postgres "$PGDATA"

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Initializing PostgreSQL data directory..."
  gosu postgres initdb -D "$PGDATA" --auth-local=trust --auth-host=scram-sha-256
  gosu postgres pg_ctl -D "$PGDATA" -o "-c listen_addresses='127.0.0.1'" -w start
  gosu postgres psql -v ON_ERROR_STOP=1 --username postgres <<-EOSQL
		CREATE USER ${POSTGRES_USER} WITH PASSWORD '${POSTGRES_PASSWORD}';
		CREATE DATABASE ${POSTGRES_DB} OWNER ${POSTGRES_USER};
		GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
EOSQL
  gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop
fi

gosu postgres pg_ctl -D "$PGDATA" -o "-c listen_addresses='127.0.0.1'" -w start

echo "Waiting for PostgreSQL..."
until gosu postgres pg_isready -q -d "$POSTGRES_DB"; do
  sleep 0.2
done

cat >/etc/bolls/django.env <<EOF
DATABASE=${DATABASE}
SQL_ENGINE=${SQL_ENGINE}
SQL_HOST=${SQL_HOST}
SQL_PORT=${SQL_PORT}
SQL_USER=${SQL_USER}
SQL_PASSWORD=${SQL_PASSWORD}
SQL_DATABASE=${SQL_DATABASE}
DEBUG=${DEBUG}
SECRET_KEY=${SECRET_KEY:-change-me-in-production}
DJANGO_ALLOWED_HOSTS=${DJANGO_ALLOWED_HOSTS}
DJANGO_USE_HTTPS=${DJANGO_USE_HTTPS:-0}
DJANGO_CSRF_TRUSTED_ORIGINS=${DJANGO_CSRF_TRUSTED_ORIGINS:-}
DJANGO_PUBLIC_URL=${DJANGO_PUBLIC_URL:-}
EMAIL_HOST_USER=${EMAIL_HOST_USER:-}
EMAIL_HOST_PASSWORD=${EMAIL_HOST_PASSWORD:-}
SOCIAL_AUTH_GOOGLE_OAUTH2_KEY=${SOCIAL_AUTH_GOOGLE_OAUTH2_KEY:-}
SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET=${SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET:-}
SOCIAL_AUTH_GITHUB_KEY=${SOCIAL_AUTH_GITHUB_KEY:-}
SOCIAL_AUTH_GITHUB_SECRET=${SOCIAL_AUTH_GITHUB_SECRET:-}
CBA_COMMENTARY_PATH=/home/bolls/web/cba-commentary.cmtx
COMMENTARY_MODULES_DIR=/home/bolls/web/commentary-modules
TRANSLATION_MODULES_DIR=/home/bolls/web/translation-modules
DICTIONARY_MODULES_DIR=/home/bolls/web/dictionary-modules
EOF

echo "Running Django migrations..."
gosu bollsuser bash -lc 'set -a && source /etc/bolls/django.env && set +a && cd /home/bolls/web && python manage.py migrate --noinput'

echo "Collecting static files..."
gosu bollsuser bash -lc 'set -a && source /etc/bolls/django.env && set +a && cd /home/bolls/web && python manage.py collectstatic --noinput --clear'

verse_count="$(gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM bolls_verses;" 2>/dev/null | tr -d '[:space:]' || true)"
verse_count="${verse_count:-0}"
if [ "${verse_count:-0}" = "0" ] && [ "${AUTO_RESTORE_DB:-0}" = "1" ]; then
  echo "Empty database detected; downloading verse backup (this may take several minutes)..."
  restore_file="/tmp/restore.sql"
  wget -q -O "$restore_file" "https://storage.googleapis.com/resurrecting-cat.appspot.com/backup.sql"
  gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$restore_file"
  if [ -f /sql/restore-indexes-sequences.sql ]; then
    gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f /sql/restore-indexes-sequences.sql
  fi
  if [ -f /sql/unaccent_plus.rules ]; then
    cp /sql/unaccent_plus.rules /usr/share/postgresql/tsearch_data/unaccent_plus.rules
    gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS unaccent;"
    gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "ALTER TEXT SEARCH DICTIONARY unaccent (RULES='unaccent_plus');"
    gosu postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
  fi
  rm -f "$restore_file"
fi

# Spanish modules the upstream backup doesn't carry. Skips anything already there.
echo "Checking bundled translations and dictionaries..."
gosu bollsuser bash -lc 'set -a && source /etc/bolls/django.env && set +a && cd /home/bolls/web && python manage.py load_translation_modules && python manage.py load_dictionary_modules'

gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

if [ "${DJANGO_USE_HTTPS:-0}" = "1" ]; then
  # Cloudflare tunnel often reaches the container over HTTP without X-Forwarded-Proto.
  sed -i "s/''      \$scheme;/''      https;/" /etc/nginx/conf.d/bolls.conf
fi

echo "Starting Bolls Bible..."
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
