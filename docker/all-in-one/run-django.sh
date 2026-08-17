#!/bin/sh
set -a
. /etc/bolls/django.env
set +a
cd /home/bolls/web
exec gunicorn bain.wsgi:application --bind 127.0.0.1:8000 -t 300
