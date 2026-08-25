#!/usr/bin/env python3
"""Convert e-Sword .bblx Bible modules into translations this app can serve.

e-Sword keeps every verse as a fragment of RTF, so the text has to be walked as
RTF rather than scrubbed with regexes: footnote markers, Strong's numbers and the
interlinear's Greek all hide inside nested groups.

Each module becomes the zip the offline downloader already expects, and
``translation-modules/books.json`` records what was built. The
``load_translation_modules`` management command reads both to fill bolls_verses.

    python3 scripts/bblx_to_csv.py --modules-dir "~/Downloads/Instalador + modulos"
    python3 scripts/bblx_to_csv.py --sample RV1995 43 3 16
"""

import argparse
import json
import os
import pathlib
import re
import sqlite3
import sys
import zipfile

import esword_rtf

REPO = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "translation-modules"
TRANSLATIONS_DIR = REPO / "django/bolls/static/translations"

# e-Sword numbers the deuterocanonicals straight after Revelation; bolls leaves
# gaps for books it orders differently. Verified against chapter counts.
DEUTERO_BOOKS = {67: 68, 68: 69, 69: 70, 70: 71, 71: 73, 72: 74, 73: 75}

DEUTERO_NAMES = {
    68: "Tobías",
    69: "Judit",
    70: "Sabiduría",
    71: "Eclesiástico",
    73: "Baruc",
    74: "1 Macabeos",
    75: "2 Macabeos",
}

# Verse ids are fixed per translation so the server and the offline copy agree:
# bookmarks travel as verse ids. Upstream ids stop around 5.2M, so these sit well
# clear of them and of each other.
MODULES = [
    ("Biblia Dios Habla Hoy Latinoamericana (1996).bblx", "DHH96", "Dios Habla Hoy, Edición Latinoamericana, 1996", 100_000_000),
    ("Biblia Dios Habla Hoy Latinoamericana con Deuterocanónicos (2002).bblx", "DHH02", "Dios Habla Hoy con Deuterocanónicos, Edición Latinoamericana, 2002", 101_000_000),
    ("Biblia Reina Valera 1995.bblx", "RV1995", "Reina-Valera 1995", 102_000_000),
    ("RVC Reina Valera Contemporanea.bblx", "RVC", "Reina Valera Contemporánea", 103_000_000),
    ("tla.bblx", "TLA", "Traducción en Lenguaje Actual", 104_000_000),
    ("Biblia Nueva Reina Valera 2000.bblx", "NRV2000", "Nueva Reina Valera 2000", 105_000_000),
    ("Biblia Reina Valera 1862.bblx", "RV1862", "Reina-Valera 1862", 106_000_000),
    ("Biblia_del_Cántaro.bblx", "RV1602", "Reina-Valera 1602, Biblia del Cántaro", 107_000_000),
    ("RV1960+ Reina Valera 1960 con Strong.bblx", "RV1960S", "Reina-Valera 1960 con números Strong", 108_000_000),
    ("Biblia Latinoamericana.bblx", "BLA", "La Biblia Latinoamericana", 109_000_000),
    ("BL95.bblx", "BL95", "Biblia Latinoamericana, 1995", 110_000_000),
    ("BJ1998.bblx", "NBJ98", "Nueva Biblia de Jerusalén, 1998", 111_000_000),
    ("INTEsp-WH+.bblx", "INTES", "Interlineal Griego-Español, Westcott-Hort (NT)", 112_000_000),
]

# The interlinear stores its Greek as raw code page bytes in a Greek font.
GREEK_MODULES = {"INTES"}

STRONG_PREFIXED = re.compile(r"[GH](\d+)")
STRONG_INTERLINEAR = re.compile(r"^\s*(\d+):")


def superscript(text):
    """Superscripts are either Strong's numbers or footnote markers we drop."""
    numbers = STRONG_PREFIXED.findall(text)
    if not numbers:
        match = STRONG_INTERLINEAR.match(text)
        numbers = [match.group(1)] if match else []
    return "".join(f"<S>{number}</S>" for number in numbers)


def renderer_for(greek):
    def font_codepage(param):
        # The interlinear keeps its Greek in a second font, as code page bytes.
        return "cp1253" if (greek and param == "1") else "cp1252"

    def on_group(text, state):
        if state.get("super"):
            return superscript(text)
        # The interlinear paints its Spanish glosses in a second colour.
        gloss = greek and state.get("color") == "2"
        if (state.get("italic") or gloss) and text.strip():
            return f"<i>{text}</i>"
        return text

    return esword_rtf.Renderer(font_codepage=font_codepage, on_group=on_group)


RENDERERS = {False: renderer_for(False), True: renderer_for(True)}


def clean(raw, greek=False, verse=None):
    text = RENDERERS[bool(greek)].render(raw)
    # A few modules carry stray control bytes that Postgres rejects.
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", text)
    text = re.sub(r"\s+", " ", text.replace("\u00a0", " "))
    text = re.sub(r"(?:\s*<br>\s*)+$", "", text)
    text = re.sub(r"^(?:\s*<br>\s*)+", "", text)
    text = re.sub(r"(?:\s*<br>\s*){2,}", "<br>", text)
    if verse:
        # Some modules print the verse number inline after a section heading.
        text = re.sub(rf"(<br>)\s*{verse}\s+(?=\S)", r"\1", text, count=1)
    return text.strip()


def open_module(path):
    return sqlite3.connect(pathlib.Path(path).resolve().as_uri() + "?mode=ro", uri=True)


def find_module(modules_dir, filename):
    candidate = modules_dir / filename
    if candidate.exists():
        return candidate
    # Some filenames on disk carry mangled accents from the original zip.
    stem = re.sub(r"[^a-z0-9]+", "", filename.lower())
    for entry in modules_dir.glob("*.bblx"):
        if re.sub(r"[^a-z0-9]+", "", entry.name.lower()) == stem:
            return entry
    return None


def convert(modules_dir, code_filter=None):
    OUT_DIR.mkdir(exist_ok=True)
    books_index = {}
    summary = []
    for filename, code, name, id_base in MODULES:
        if code_filter and code != code_filter:
            continue
        path = find_module(modules_dir, filename)
        if not path:
            print(f"  !! missing module for {code}: {filename}", file=sys.stderr)
            continue
        greek = code in GREEK_MODULES
        con = open_module(path)
        rows = con.execute("SELECT Book, Chapter, Verse, Scripture FROM Bible ORDER BY Book, Chapter, Verse")
        chapters = {}
        verses = []
        empty = 0
        for book, chapter, verse, scripture in rows:
            book = DEUTERO_BOOKS.get(book, book)
            text = clean(scripture, greek, verse)
            # Modules keep placeholders for verses an edition doesn't carry;
            # bolls leaves those verse numbers out instead of showing blanks.
            if not text:
                empty += 1
                continue
            chapters[book] = max(chapters.get(book, 0), chapter)
            verses.append({
                "pk": id_base + len(verses),
                "translation": code,
                "book": book,
                "chapter": chapter,
                "verse": verse,
                "text": text,
            })
        con.close()
        books_index[code] = chapters
        size = write_translation(code, verses)
        summary.append((code, name, len(verses), empty, len(chapters), size))
        print(f"  {code:<8} {len(verses):>6} verses, {len(chapters):>2} books, {size/1e6:.1f} MB"
              + (f", {empty} skipped" if empty else ""))
    return books_index, summary


def build_books(books_index):
    """Reuse the app's Spanish book names, adding the deuterocanonicals."""
    with open(REPO / "imba/src/data/translations_books.json", encoding="utf-8") as handle:
        existing = json.load(handle)
    spanish = {book["bookid"]: book for book in existing["RV1960"]}
    catholic = {book["bookid"]: book for book in existing["NRSVCE"]}
    output = {}
    for code, chapters in books_index.items():
        books = []
        for bookid in sorted(chapters):
            if bookid in spanish:
                base = spanish[bookid]
                books.append({
                    "bookid": bookid,
                    "chronorder": base["chronorder"],
                    "name": base["name"],
                    "chapters": chapters[bookid],
                })
            else:
                base = catholic.get(bookid, {})
                books.append({
                    "bookid": bookid,
                    "chronorder": base.get("chronorder", bookid),
                    "name": DEUTERO_NAMES.get(bookid, base.get("name", str(bookid))),
                    "chapters": chapters[bookid],
                })
        output[code] = books
    return output


def write_translation(code, verses):
    """Same zip the offline downloader serves; the importer reads it as well."""
    target = TRANSLATIONS_DIR / f"{code}.zip"
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr(f"{code}.json", json.dumps(verses, ensure_ascii=False))
    return target.stat().st_size


def register(books):
    """Add the new translations to the data files the reader is built from."""
    names = {code: name for _, code, name, _base in MODULES}
    books_path = REPO / "imba/src/data/translations_books.json"
    with open(books_path, encoding="utf-8") as handle:
        all_books = json.load(handle)
    all_books.update(books)
    with open(books_path, "w", encoding="utf-8") as handle:
        json.dump(all_books, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    languages_path = REPO / "imba/src/data/languages.json"
    with open(languages_path, encoding="utf-8") as handle:
        languages = json.load(handle)
    spanish = next(entry for entry in languages if entry["language"].startswith("Spanish"))
    known = {item["short_name"] for item in spanish["translations"]}
    stamp = int(pathlib.Path(__file__).stat().st_mtime * 1000)
    for code in books:
        if code in known:
            continue
        spanish["translations"].append({
            "short_name": code,
            "full_name": names.get(code, code),
            "updated": stamp,
        })
    with open(languages_path, "w", encoding="utf-8") as handle:
        json.dump(languages, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"  registered {len(books)} translations in languages.json and translations_books.json")


def sample(modules_dir, code, book, chapter, verse):
    for filename, module_code, _name, _base in MODULES:
        if module_code != code:
            continue
        path = find_module(modules_dir, filename)
        con = open_module(path)
        source = {v: k for k, v in DEUTERO_BOOKS.items()}.get(book, book)
        row = con.execute(
            "SELECT Scripture FROM Bible WHERE Book=? AND Chapter=? AND Verse=?", (source, chapter, verse)
        ).fetchone()
        con.close()
        if not row:
            print("no such verse")
            return
        print("RAW  :", repr(row[0])[:600])
        print("CLEAN:", clean(row[0], code in GREEK_MODULES, verse))
        return
    print(f"unknown translation {code}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modules-dir", default=os.path.expanduser("~/Downloads/Instalador + módulos"))
    parser.add_argument("--only", help="convert a single translation code")
    parser.add_argument("--sample", nargs=4, metavar=("CODE", "BOOK", "CHAPTER", "VERSE"))
    parser.add_argument("--no-register", action="store_true", help="skip updating the reader's data files")
    args = parser.parse_args()

    modules_dir = pathlib.Path(os.path.expanduser(args.modules_dir))
    if not modules_dir.is_dir():
        parser.error(f"no such directory: {modules_dir}")

    if args.sample:
        code, book, chapter, verse = args.sample
        sample(modules_dir, code, int(book), int(chapter), int(verse))
        return

    books_index, _ = convert(modules_dir, args.only)
    if books_index:
        books = build_books(books_index)
        with open(OUT_DIR / "books.json", "w", encoding="utf-8") as handle:
            json.dump(books, handle, ensure_ascii=False, indent=1)
        print(f"  books.json written for {len(books)} translations")
        if not args.no_register:
            register(books)


if __name__ == "__main__":
    main()
