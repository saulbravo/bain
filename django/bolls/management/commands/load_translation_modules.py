"""Import the bundled Spanish translations into bolls_verses.

``scripts/bblx_to_csv.py`` turns e-Sword modules into the same zipped JSON the
offline downloader serves, and lists them in ``translation-modules/books.json``.
They ship with the image because the upstream database backup only carries the
translations bolls.life hosts. Anything already in the database is left alone, so
this is safe to run on every boot.
"""

import json
import os
import pathlib
import zipfile

from django.core.management.base import BaseCommand
from django.db import connection, transaction

from bolls.models import Verses

BASE_DIR = pathlib.Path(__file__).resolve().parents[3]
TRANSLATIONS_DIR = BASE_DIR / "bolls" / "static" / "translations"
BATCH_SIZE = 5000


def manifest_path():
    configured = os.environ.get("TRANSLATION_MODULES_DIR")
    candidates = [pathlib.Path(configured)] if configured else [
        # Django runs from the repo's `django/` folder in development and from
        # its own copy in the image, so look next to both.
        BASE_DIR / "translation-modules",
        BASE_DIR.parent / "translation-modules",
    ]
    for directory in candidates:
        path = directory / "books.json"
        if path.is_file():
            return path
    return None


def bundled_codes():
    path = manifest_path()
    if not path:
        return []
    with open(path, encoding="utf-8") as handle:
        return sorted(json.load(handle))


def reset_id_sequence():
    """Keep the identity sequence ahead of the explicit ids we just inserted."""
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT setval(pg_get_serial_sequence('bolls_verses', 'id'),"
            " (SELECT COALESCE(MAX(id), 0) + 1 FROM bolls_verses), false)"
        )


class Command(BaseCommand):
    help = "Import bundled translations into bolls_verses if they are missing."

    def add_arguments(self, parser):
        parser.add_argument("--only", help="import a single translation code")
        parser.add_argument(
            "--replace",
            action="store_true",
            help="delete and reimport translations that are already present",
        )

    def handle(self, *args, **options):
        codes = bundled_codes()
        if not codes:
            self.stdout.write(self.style.WARNING("No bundled translations found."))
            return

        only = options.get("only")
        replace = options.get("replace")
        imported = 0
        for code in codes:
            if only and code != only:
                continue
            archive = TRANSLATIONS_DIR / f"{code}.zip"
            if not archive.is_file():
                self.stdout.write(self.style.WARNING(f"  {code}: {archive} is missing"))
                continue
            exists = Verses.objects.filter(translation=code).exists()
            if exists and not replace:
                continue

            # One transaction per translation: a failure part way through would
            # otherwise leave rows behind that make the import look finished.
            with transaction.atomic():
                if exists:
                    deleted, _ = Verses.objects.filter(translation=code).delete()
                    self.stdout.write(f"  {code}: removed {deleted} existing verses")
                written = self.load(archive, code)
                reset_id_sequence()
            imported += 1
            self.stdout.write(self.style.SUCCESS(f"  {code}: imported {written} verses"))

        if not imported:
            self.stdout.write("All bundled translations are already loaded.")

    def load(self, archive, code):
        with zipfile.ZipFile(archive) as bundle:
            with bundle.open(f"{code}.json") as handle:
                rows = json.load(handle)
        verses = [
            Verses(
                # Fixed ids keep bookmarks pointing at the same verse whether
                # they were made online or from the offline copy.
                id=row["pk"],
                translation=code,
                book=row["book"],
                chapter=row["chapter"],
                verse=row["verse"],
                text=row["text"],
            )
            for row in rows
        ]
        Verses.objects.bulk_create(verses, batch_size=BATCH_SIZE)
        return len(verses)
