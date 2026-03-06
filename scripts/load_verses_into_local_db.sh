#!/usr/bin/env bash
# Load verse data into the local database (Docker).
# Run from project root. Requires docker compose with service name "django".
#
# Usage:
#   ./scripts/load_verses_into_local_db.sh [TRANSLATION]
#   TRANSLATION defaults to YLT.
#
# Examples:
#   ./scripts/load_verses_into_local_db.sh
#   ./scripts/load_verses_into_local_db.sh YLT
#   ./scripts/load_verses_into_local_db.sh KJV

set -e
TRANSLATION="${1:-YLT}"
echo "Loading translation: $TRANSLATION"
docker compose exec django python manage.py load_verses --translation "$TRANSLATION" --replace
echo "Done. Open the app and choose a book/chapter/verse to verify."
