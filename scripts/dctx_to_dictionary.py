#!/usr/bin/env python3
"""Convert e-Sword .dctx dictionaries into dictionaries this app can serve.

The Strong's-keyed ones are the point of this: tapping a Hebrew or Greek word in
the reader looks the number up in whichever dictionary is selected, and until now
every dictionary in the app answered in English or Russian.

Each module becomes the zip the offline downloader already expects, and
``dictionary-modules/dictionaries.json`` records what was built. The
``load_dictionary_modules`` management command reads both to fill
bolls_dictionary.

    python3 scripts/dctx_to_dictionary.py --modules-dir "~/Downloads/Instalador + modulos"
    python3 scripts/dctx_to_dictionary.py --sample STRES H430
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
OUT_DIR = REPO / "dictionary-modules"
DICTIONARIES_DIR = REPO / "django/bolls/static/dictionaries"

# The abbreviation is what the URL and the saved preference use, and the column
# holding it stops at eight characters.
MODULES = [
    ("strongspa.dctx", "STRES", "Diccionario Strong en español, hebreo y griego"),
    ("Diccionario de Hebreo Bíblico de Moisés Chávez con números Strong.dctx", "CHAVEZ",
     "Diccionario de Hebreo Bíblico, Moisés Chávez"),
    ("Diccionario Vine de palabras del Nuevo Testamento con Números Strong.dctx", "VINENT",
     "Diccionario Vine, palabras del Nuevo Testamento"),
    ("Diccionario Vine de palabras del Antiguo Testamento con Números Strong.dctx", "VINEAT",
     "Diccionario Vine, palabras del Antiguo Testamento"),
]

# Hebrew and Greek runs are stored as bytes in these legacy code pages.
FONT_CODEPAGES = {"1": "cp1253", "2": "cp1255"}

STRONG_TOPIC = re.compile(r"^[GH]\d+$")
STRONG_REFERENCE = re.compile(r"^[GH]\d+$")
HEADWORD = re.compile(r"^(.{1,60}?)<br>((?:<b>)?[^<>]{1,40}(?:</b>)?)<br>")
# A transliteration is Latin letters and nothing else; a numbered sense or a
# verse reference on that line means the module isn't laid out that way.
TRANSLITERATION = re.compile(r"^[A-Za-zÀ-ÿ'\u2019\u02bc\u0304\u0306 -]{1,40}$")
TAGS = re.compile(r"<[^>]+>")
SHORT_DEFINITION_LIMIT = 160


def strip_tags(text):
    return re.sub(r"\s+", " ", TAGS.sub("", text)).strip()


def build_renderer(glosses, foreign):
    def on_group(text, state):
        stripped = text.strip()
        # The headword is the first run set in a Hebrew or Greek font.
        if stripped and not foreign and state.get("codepage") != "cp1252":
            word = strip_tags(stripped)
            if word and not word.isascii():
                foreign.append(word)
        # Cross-references to other Strong's numbers, which the reader turns
        # into taps of their own.
        if STRONG_REFERENCE.match(strip_tags(stripped)) and (
            state.get("underline") or state.get("color") == "14"
        ):
            reference = strip_tags(stripped)
            return f"<a href=S:{reference}>{reference}</a>"
        # The words the Reina-Valera actually used for this term.
        if state.get("color") == "13" and stripped:
            glosses.append(strip_tags(stripped))
        if not stripped:
            return text
        if state.get("bold"):
            return f"<b>{text}</b>"
        if state.get("italic"):
            return f"<i>{text}</i>"
        return text

    return esword_rtf.Renderer(
        font_codepage=lambda param: FONT_CODEPAGES.get(param, "cp1252"),
        on_group=on_group,
    )


def clean(text):
    text = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", text)
    text = re.sub(r"[ \t]+", " ", text.replace("\u00a0", " "))
    text = re.sub(r"(?:\s*<br>\s*)+$", "", text)
    text = re.sub(r"^(?:\s*<br>\s*)+", "", text)
    return text.strip()


def convert_entry(topic, raw):
    if raw is None:
        return None
    raw = raw.strip()
    if len(raw) > 1 and raw[0] == '"' and raw[-1] == '"':
        raw = raw[1:-1]

    glosses = []
    foreign = []
    text = clean(build_renderer(glosses, foreign).render(raw))
    if not text:
        return None

    lexeme = foreign[0] if foreign else ""
    transliteration = ""
    definition = text
    # Strong's dictionaries lead with the word, then its transliteration, each on
    # its own line. Other modules run the word into the text and keep it there.
    head = HEADWORD.match(text)
    if lexeme and head and strip_tags(head.group(1)) == lexeme:
        candidate = strip_tags(head.group(2))
        if TRANSLITERATION.match(candidate):
            transliteration = candidate
            definition = text[head.end():].strip()

    short_definition = "; ".join(glosses).strip(" .;")
    if len(short_definition) > SHORT_DEFINITION_LIMIT:
        short_definition = short_definition[:SHORT_DEFINITION_LIMIT].rsplit(",", 1)[0]

    return {
        "topic": topic,
        "definition": definition or text,
        "lexeme": lexeme or topic,
        "transliteration": transliteration,
        "pronunciation": "",
        "short_definition": short_definition,
    }


def open_module(path):
    return sqlite3.connect(pathlib.Path(path).resolve().as_uri() + "?mode=ro", uri=True)


def find_module(modules_dir, filename):
    candidate = modules_dir / filename
    if candidate.exists():
        return candidate
    # Some filenames on disk carry mangled accents from the original zip.
    stem = re.sub(r"[^a-z0-9]+", "", filename.lower())
    for entry in modules_dir.glob("*.dctx"):
        if re.sub(r"[^a-z0-9]+", "", entry.name.lower()) == stem:
            return entry
    return None


def read_entries(path):
    con = open_module(path)
    rows = con.execute("SELECT Topic, Definition FROM Dictionary")
    entries = []
    for topic, definition in rows:
        topic = (topic or "").strip().strip("'").strip()
        if not topic:
            continue
        entry = convert_entry(topic, definition)
        if entry:
            entries.append(entry)
    con.close()
    return entries


def convert(modules_dir, code_filter=None):
    OUT_DIR.mkdir(exist_ok=True)
    manifest = {}
    for filename, code, name in MODULES:
        if code_filter and code != code_filter:
            continue
        path = find_module(modules_dir, filename)
        if not path:
            print(f"  !! missing module for {code}: {filename}", file=sys.stderr)
            continue
        entries = read_entries(path)
        strong_keyed = sum(1 for entry in entries if STRONG_TOPIC.match(entry["topic"]))
        target = DICTIONARIES_DIR / f"{code}.zip"
        with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            archive.writestr(f"{code}.json", json.dumps(entries, ensure_ascii=False))
        manifest[code] = name
        print(f"  {code:<8} {len(entries):>6} entries, {strong_keyed:>6} keyed by Strong's number,"
              f" {target.stat().st_size/1e6:.1f} MB")
    return manifest


def register(manifest):
    """Add the new dictionaries to the list the reader is built from."""
    path = REPO / "imba/src/data/dictionaries.json"
    with open(path, encoding="utf-8") as handle:
        dictionaries = json.load(handle)
    known = {item["abbr"] for item in dictionaries}
    for abbr, name in manifest.items():
        if abbr not in known:
            dictionaries.append({"abbr": abbr, "name": name})
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(dictionaries, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"  registered {len(manifest)} dictionaries in dictionaries.json")


def sample(modules_dir, code, topic):
    for filename, module_code, _name in MODULES:
        if module_code != code:
            continue
        path = find_module(modules_dir, filename)
        con = open_module(path)
        rows = {t.strip().strip("'").strip(): d for t, d in con.execute("SELECT Topic, Definition FROM Dictionary")}
        con.close()
        raw = rows.get(topic.upper())
        if raw is None:
            print(f"no entry for {topic}")
            return
        print("RAW  :", repr(raw)[:600])
        print("CLEAN:", json.dumps(convert_entry(topic.upper(), raw), ensure_ascii=False, indent=1))
        return
    print(f"unknown dictionary {code}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modules-dir", default=os.path.expanduser("~/Downloads/Instalador + módulos"))
    parser.add_argument("--only", help="convert a single dictionary code")
    parser.add_argument("--sample", nargs=2, metavar=("CODE", "TOPIC"))
    parser.add_argument("--no-register", action="store_true", help="skip updating the reader's data files")
    args = parser.parse_args()

    modules_dir = pathlib.Path(os.path.expanduser(args.modules_dir))
    if not modules_dir.is_dir():
        parser.error(f"no such directory: {modules_dir}")

    if args.sample:
        sample(modules_dir, args.sample[0], args.sample[1])
        return

    manifest = convert(modules_dir, args.only)
    if manifest:
        with open(OUT_DIR / "dictionaries.json", "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, ensure_ascii=False, indent=1)
            handle.write("\n")
        if not args.no_register:
            register(manifest)


if __name__ == "__main__":
    main()
