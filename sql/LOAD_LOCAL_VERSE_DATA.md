# Loading verse data into the local database

To get full book/chapter/verse content in your local DB (so "Choose verse" and chapter views work for all books), use the `load_verses` management command. It fetches from the public bolls.life API and inserts into `bolls_verses`.

## Quick start (Docker)

From the project root, with containers running:

```bash
# Load YLT (default)
./scripts/load_verses_into_local_db.sh

# Or specify translation
./scripts/load_verses_into_local_db.sh YLT
./scripts/load_verses_into_local_db.sh KJV
```

Or run the Django command directly:

```bash
docker compose exec django python manage.py load_verses --translation YLT --replace
```

## Options

- `--translation YLT` — Translation code (default: YLT). Used when fetching from the default URL.
- `--url https://...` — Custom URL that returns the same JSON shape as `get-translation` (array of `{ translation, book, chapter, verse, text }`).
- `--file /path/to/verses.json` — Load from a local JSON file instead of the network.
- `--replace` — Delete existing verses for that translation before inserting (recommended when re-loading).

## Alternative: load from CSV

If you have a CSV of verses (columns: translation, book, chapter, verse, text), copy it into the database container and use `\copy`:

```bash
docker cp ./verses.csv database:verses.csv
docker exec -i database psql -U postgres_user -d postgres_db -c "\copy bolls_verses(translation, book, chapter, verse, text) FROM 'verses.csv' DELIMITER ',' CSV HEADER;"
```

See `HOW_TO_ADD_A_NEW_TRANSLATION.md` for obtaining and formatting verse data (e.g. from MyBible modules).
