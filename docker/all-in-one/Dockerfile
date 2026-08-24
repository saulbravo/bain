# syntax=docker/dockerfile:1

##############
# Imba build #
##############
FROM node AS imba-builder

WORKDIR /build
COPY imba/ .
RUN npm run build

FROM node AS imba-runner

WORKDIR /build
COPY --from=imba-builder /build/dist .
COPY --from=imba-builder /build/public ./public/
COPY --from=imba-builder /build/src/data ./src/data/
COPY --from=imba-builder /build/package*.json ./
COPY --from=imba-builder /build/node_modules ./node_modules
RUN npm prune --omit=dev

################
# Django wheels #
################
FROM python:3.12-bookworm AS django-builder

WORKDIR /usr/src/bolls
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN rm -f /etc/apt/sources.list.d/debian.sources \
    && echo 'deb http://deb.debian.org/debian bookworm main' > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY django/requirements.txt .
RUN pip install --upgrade pip \
    && pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/bolls/wheels -r requirements.txt

#################
# All-in-one app #
#################
FROM python:3.12-bookworm

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV HOME=/home/bolls
ENV BOLLS_HOME=/home/bolls/web
ENV PGDATA=/var/lib/postgresql/data

RUN rm -f /etc/apt/sources.list.d/debian.sources \
    && echo 'deb http://deb.debian.org/debian bookworm main' > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99no-check-valid \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends \
        nginx \
        postgresql \
        postgresql-contrib \
        supervisor \
        curl \
        unzip \
        netcat-openbsd \
        gosu \
        wget \
        ca-certificates \
        nodejs \
        npm \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

RUN addgroup --system bolls \
    && adduser --system --ingroup bolls bollsuser

RUN mkdir -p "$BOLLS_HOME" "$BOLLS_HOME/static" /app/imba /etc/bolls /var/log/supervisor

WORKDIR $BOLLS_HOME

COPY --from=django-builder /usr/src/bolls/wheels /wheels
COPY --from=django-builder /usr/src/bolls/requirements.txt .
RUN pip install --no-cache /wheels/*

COPY django/ $BOLLS_HOME/
COPY sql/unaccent_plus.rules /sql/unaccent_plus.rules
COPY sql/restore-indexes-sequences.sql /sql/restore-indexes-sequences.sql
COPY ["Comentario Biblico Adventista Tomos 1 al 7.cmtx", "/home/bolls/web/cba-commentary.cmtx"]
COPY commentary-modules/ /home/bolls/web/commentary-modules/

RUN cd "$BOLLS_HOME/bolls/static/translations" \
    && for f in *.zip; do [ -f "$f" ] && unzip -o "$f" -d .; done \
    && cd "$BOLLS_HOME/bolls/static/dictionaries" \
    && for f in *.zip; do [ -f "$f" ] && unzip -o "$f" -d .; done

COPY --from=imba-runner /build /app/imba/

COPY docker/all-in-one/nginx.conf /etc/nginx/conf.d/bolls.conf
COPY docker/all-in-one/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/all-in-one/entrypoint.sh /entrypoint.sh
COPY docker/all-in-one/run-django.sh /usr/local/bin/run-django.sh
COPY docker/all-in-one/run-imba.sh /usr/local/bin/run-imba.sh

COPY docker/all-in-one/run-postgres.sh /usr/local/bin/run-postgres.sh

RUN chmod +x /entrypoint.sh /usr/local/bin/run-django.sh /usr/local/bin/run-imba.sh /usr/local/bin/run-postgres.sh \
    && chown -R bollsuser:bolls "$BOLLS_HOME" \
    && chown -R postgres:postgres /var/lib/postgresql

VOLUME ["/var/lib/postgresql/data"]

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -fsS http://127.0.0.1/get-text/YLT/1/1/ >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
