"""
Load verse data into the local bolls_verses table.

Fetches from the public bolls.life API (or a custom URL / local JSON file)
and bulk-inserts into the database. Use this to populate your local DB
so "Choose verse" and chapter views work for all books.

Examples:

  # Load YLT from bolls.life (default)
  python manage.py load_verses --translation YLT

  # Load from a custom API URL (same JSON shape as get-translation)
  python manage.py load_verses --translation KJV --url https://bolls.life/get-translation/KJV/

  # Load from a local JSON file (array of { translation, book, chapter, verse, text })
  python manage.py load_verses --file /path/to/verses.json

  # Clear existing YLT verses before loading (replace)
  python manage.py load_verses --translation YLT --replace
"""
import json
import urllib.request
from django.core.management.base import BaseCommand
from django.db import transaction

from bolls.models import Verses


DEFAULT_BASE_URL = "https://bolls.life/get-translation"


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Bible-Local-Loader/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return json.loads(resp.read().decode())


def verses_from_api_payload(data):
    """Convert get-translation API response to list of (translation, book, chapter, verse, text)."""
    out = []
    for row in data:
        if not isinstance(row, dict):
            continue
        trans = row.get("translation") or ""
        book = row.get("book")
        chapter = row.get("chapter")
        verse = row.get("verse")
        text = row.get("text") or ""
        if book is None or chapter is None or verse is None:
            continue
        try:
            book = int(book)
            chapter = int(chapter)
            verse = int(verse)
        except (TypeError, ValueError):
            continue
        out.append((trans, book, chapter, verse, text))
    return out


class Command(BaseCommand):
    help = "Load verse data into bolls_verses from bolls.life API or a local JSON file."

    def add_arguments(self, parser):
        parser.add_argument(
            "--translation",
            type=str,
            default="YLT",
            help="Translation code to load (e.g. YLT, KJV). Used with --url or default bolls.life.",
        )
        parser.add_argument(
            "--url",
            type=str,
            default=None,
            help="URL that returns JSON array of verses (e.g. get-translation endpoint).",
        )
        parser.add_argument(
            "--file",
            type=str,
            default=None,
            help="Path to local JSON file (array of { translation, book, chapter, verse, text }).",
        )
        parser.add_argument(
            "--replace",
            action="store_true",
            help="Delete existing verses for this translation before inserting.",
        )

    def handle(self, *args, **options):
        translation = (options.get("translation") or "YLT").strip()
        url = options.get("url")
        filepath = options.get("file")
        replace = options.get("replace")

        if filepath:
            self.stdout.write(f"Loading from file: {filepath}")
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
        else:
            api_url = url or f"{DEFAULT_BASE_URL}/{translation}/"
            self.stdout.write(f"Fetching: {api_url}")
            data = fetch_json(api_url)

        if not isinstance(data, list):
            self.stdout.write(self.style.ERROR("Expected a JSON array of verse objects."))
            return

        rows = verses_from_api_payload(data)
        if not rows:
            self.stdout.write(self.style.WARNING("No valid verses found in the response."))
            return

        # Optional: filter to single translation when loading from file
        if filepath and translation:
            rows = [r for r in rows if (r[0] or "").strip().upper() == translation.upper()]
            if not rows:
                self.stdout.write(
                    self.style.WARNING(
                        f"No verses with translation '{translation}' in file."
                    )
                )
                return

        if replace and rows:
            replace_translation = rows[0][0]
            deleted, _ = Verses.objects.filter(translation=replace_translation).delete()
            self.stdout.write(f"Deleted {deleted} existing verses for {replace_translation}.")

        self.stdout.write(f"Inserting {len(rows)} verses...")
        batch_size = 2000
        created = 0
        with transaction.atomic():
            for i in range(0, len(rows), batch_size):
                batch = rows[i : i + batch_size]
                objs = [
                    Verses(
                        translation=r[0],
                        book=r[1],
                        chapter=r[2],
                        verse=r[3],
                        text=r[4],
                    )
                    for r in batch
                ]
                Verses.objects.bulk_create(objs)
                created += len(objs)
                self.stdout.write(f"  {created} / {len(rows)}")

        self.stdout.write(self.style.SUCCESS(f"Done. Inserted {created} verses."))
