"""Registry and reader for e-Sword commentary modules (``.cmtx`` SQLite files).

Every module shares the same schema: a one row ``Details`` table holding the
title, and a ``Verses`` table whose rows cover a range of chapters/verses. Drop
a new ``.cmtx`` file into the modules directory and it shows up in the picker.
"""

import os
import pathlib
import re
import sqlite3
import threading
import unicodedata

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

CBA_FILENAME = "Comentario Biblico Adventista Tomos 1 al 7.cmtx"
# The module's own Details row misspells it as "Cometario".
CBA_DISPLAY_NAME = "Comentario Bíblico Adventista"

# Legacy single-file setting, kept so existing deployments keep working.
CBA_COMMENTARY_PATH = os.environ.get("CBA_COMMENTARY_PATH", os.path.join(BASE_DIR, CBA_FILENAME))

DEFAULT_COMMENTARY_ID = "cba"

_registry_lock = threading.Lock()
_registry_cache = None


def _module_directories():
    configured = os.environ.get("COMMENTARY_MODULES_DIR")
    if configured:
        return [path for path in configured.split(os.pathsep) if path]
    # Django runs from the repo's `django/` folder in development and from its
    # own copy in the image, so look next to both.
    return [
        os.path.join(BASE_DIR, "commentary-modules"),
        os.path.join(os.path.dirname(BASE_DIR), "commentary-modules"),
    ]


# Tab labels have to stay short. Anything not listed falls back to the module's
# own abbreviation with its noisier bits trimmed off.
SHORT_NAME_OVERRIDES = {
    "cba": "CBA",
    "elena-g-white-new": "EGW",
    "biblia-textual-cmt": "Textual",
    "nt-peshita": "Peshita",
}


def _short_name(identifier, abbreviation, name):
    if identifier in SHORT_NAME_OVERRIDES:
        return SHORT_NAME_OVERRIDES[identifier]
    label = str(abbreviation or name or "").strip()
    label = re.sub(r"\s*\([^)]*\)", "", label)
    label = re.sub(r"\s+", " ", label.replace('"', "").replace("'", "")).strip(" .")
    return label or str(name or "")


def _slugify(value):
    text = unicodedata.normalize("NFKD", str(value or ""))
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text


def _read_only_uri(path):
    # Module filenames contain spaces and accents, which have to be percent-encoded
    # before SQLite will accept them as a URI.
    return pathlib.Path(path).as_uri() + "?mode=ro"


def _read_details(path):
    try:
        with sqlite3.connect(_read_only_uri(path), uri=True) as con:
            cur = con.cursor()
            cur.execute("SELECT Description, Abbreviation FROM Details LIMIT 1")
            row = cur.fetchone()
    except Exception:
        return None
    if not row:
        return None
    description = (row[0] or "").strip()
    abbreviation = (row[1] or "").strip()
    if not description and not abbreviation:
        return None
    return {
        "name": description or abbreviation,
        "abbreviation": abbreviation or description,
    }


def _build_registry():
    seen_paths = set()
    modules = {}

    def add(path, forced_id=None):
        real = os.path.realpath(path)
        if real in seen_paths or not os.path.exists(real):
            return
        details = _read_details(real)
        if not details:
            return
        seen_paths.add(real)
        base = forced_id or _slugify(details["abbreviation"]) or _slugify(os.path.basename(real))
        identifier = base
        suffix = 2
        while identifier in modules:
            identifier = f"{base}-{suffix}"
            suffix += 1
        name = CBA_DISPLAY_NAME if identifier == DEFAULT_COMMENTARY_ID else details["name"]
        modules[identifier] = {
            "id": identifier,
            "name": name,
            "abbreviation": details["abbreviation"],
            "short": _short_name(identifier, details["abbreviation"], name),
            "path": real,
        }

    # The Adventist commentary keeps a stable id so saved preferences survive. In
    # Docker the file arrives through a mount; outside it, it sits in the repo root.
    add(CBA_COMMENTARY_PATH, DEFAULT_COMMENTARY_ID)
    if DEFAULT_COMMENTARY_ID not in modules:
        add(os.path.join(os.path.dirname(BASE_DIR), CBA_FILENAME), DEFAULT_COMMENTARY_ID)
    for directory in _module_directories():
        if not os.path.isdir(directory):
            continue
        for filename in sorted(os.listdir(directory)):
            if filename.lower().endswith(".cmtx"):
                add(os.path.join(directory, filename))

    return modules


def get_registry(refresh=False):
    global _registry_cache
    with _registry_lock:
        if _registry_cache is None or refresh:
            _registry_cache = _build_registry()
        return _registry_cache


def list_commentaries():
    registry = get_registry()
    entries = [
        {
            "id": item["id"],
            "name": item["name"],
            "abbreviation": item["abbreviation"],
            "short": item["short"],
        }
        for item in registry.values()
    ]
    # Default first, then alphabetical, so the picker opens on a familiar name.
    entries.sort(key=lambda item: (item["id"] != DEFAULT_COMMENTARY_ID, item["name"].lower()))
    return entries


def resolve_commentary(commentary_id):
    registry = get_registry()
    if commentary_id and commentary_id in registry:
        return registry[commentary_id]
    if DEFAULT_COMMENTARY_ID in registry:
        return registry[DEFAULT_COMMENTARY_ID]
    for item in registry.values():
        return item
    return None


def read_comments(module, book, chapter, verse):
    if not module or not os.path.exists(module["path"]):
        return []
    with sqlite3.connect(_read_only_uri(module["path"]), uri=True) as con:
        cur = con.cursor()
        cur.execute(
            """
            SELECT Comments
            FROM Verses
            WHERE Book = ?
              AND ChapterBegin <= ?
              AND ChapterEnd >= ?
              AND VerseBegin <= ?
              AND VerseEnd >= ?
            ORDER BY ChapterBegin, VerseBegin
            """,
            (book, chapter, chapter, verse, verse),
        )
        return [row[0] for row in cur.fetchall() if row and row[0]]
