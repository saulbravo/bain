"""Import the bundled Spanish dictionaries into bolls_dictionary.

``scripts/dctx_to_dictionary.py`` turns e-Sword modules into the same zipped JSON
the offline downloader serves, and lists them in
``dictionary-modules/dictionaries.json``. They ship with the image because the
upstream database backup only carries the dictionaries bolls.life hosts, all of
which answer in English or Russian. Anything already in the database is left
alone, so this is safe to run on every boot.
"""

import json
import os
import pathlib
import zipfile

from django.core.management.base import BaseCommand
from django.db import transaction

from bolls.models import Dictionary

BASE_DIR = pathlib.Path(__file__).resolve().parents[3]
DICTIONARIES_DIR = BASE_DIR / "bolls" / "static" / "dictionaries"
BATCH_SIZE = 2000


def manifest_path():
    configured = os.environ.get("DICTIONARY_MODULES_DIR")
    candidates = [pathlib.Path(configured)] if configured else [
        # Django runs from the repo's `django/` folder in development and from
        # its own copy in the image, so look next to both.
        BASE_DIR / "dictionary-modules",
        BASE_DIR.parent / "dictionary-modules",
    ]
    for directory in candidates:
        path = directory / "dictionaries.json"
        if path.is_file():
            return path
    return None


def bundled_codes():
    path = manifest_path()
    if not path:
        return []
    with open(path, encoding="utf-8") as handle:
        return sorted(json.load(handle))


class Command(BaseCommand):
    help = "Import bundled dictionaries into bolls_dictionary if they are missing."

    def add_arguments(self, parser):
        parser.add_argument("--only", help="import a single dictionary code")
        parser.add_argument(
            "--replace",
            action="store_true",
            help="delete and reimport dictionaries that are already present",
        )

    def handle(self, *args, **options):
        codes = bundled_codes()
        if not codes:
            self.stdout.write(self.style.WARNING("No bundled dictionaries found."))
            return

        only = options.get("only")
        replace = options.get("replace")
        imported = 0
        for code in codes:
            if only and code != only:
                continue
            archive = DICTIONARIES_DIR / f"{code}.zip"
            if not archive.is_file():
                self.stdout.write(self.style.WARNING(f"  {code}: {archive} is missing"))
                continue
            exists = Dictionary.objects.filter(dictionary=code).exists()
            if exists and not replace:
                continue

            # One transaction per dictionary: a failure part way through would
            # otherwise leave rows behind that make the import look finished.
            with transaction.atomic():
                if exists:
                    deleted, _ = Dictionary.objects.filter(dictionary=code).delete()
                    self.stdout.write(f"  {code}: removed {deleted} existing entries")
                written = self.load(archive, code)
            imported += 1
            self.stdout.write(self.style.SUCCESS(f"  {code}: imported {written} entries"))

        if not imported:
            self.stdout.write("All bundled dictionaries are already loaded.")

    def load(self, archive, code):
        with zipfile.ZipFile(archive) as bundle:
            with bundle.open(f"{code}.json") as handle:
                rows = json.load(handle)
        entries = [
            Dictionary(
                dictionary=code,
                topic=row["topic"],
                definition=row["definition"],
                lexeme=row.get("lexeme", ""),
                transliteration=row.get("transliteration", ""),
                pronunciation=row.get("pronunciation", ""),
                short_definition=row.get("short_definition") or None,
            )
            for row in rows
        ]
        Dictionary.objects.bulk_create(entries, batch_size=BATCH_SIZE)
        return len(entries)
