# Adding translations from e-Sword modules

The upstream database backup only carries the translations bolls.life hosts, so
the Spanish Bibles that came from e-Sword (`.bblx` files) are converted here and
shipped with the repo.

## Building a module

```bash
python3 scripts/bblx_to_csv.py --modules-dir "~/Downloads/Instalador + módulos"
```

For every entry in that script's `MODULES` list this writes
`django/bolls/static/translations/<CODE>.zip` (the same zipped JSON the offline
downloader already serves), records the book lists in
`translation-modules/books.json`, and adds the translation to
`imba/src/data/languages.json` and `imba/src/data/translations_books.json`, which
is what the reader and Django's `/get-books/` both read.

To see what the converter does with a single verse before running the whole
thing:

```bash
python3 scripts/bblx_to_csv.py --sample RV1995 43 3 16
```

Adding another module means adding a row to `MODULES` with an unused translation
code and an unused id base, then rerunning. `--no-register` skips touching the
reader's data files.

## Loading it into the database

```bash
make load-translations          # or: manage.py load_translation_modules
```

The command imports any bundled translation the database doesn't have yet and
leaves the rest alone, so the all-in-one image runs it on every boot, after the
verse backup is restored. Use `--replace` to reimport one that is already there,
and `--only CODE` to work on a single translation.

## Things the converter has to handle

e-Sword stores each verse as a fragment of RTF, so the text is parsed as RTF
rather than scrubbed with regexes.

- Superscript groups are either Strong's numbers or footnote markers. Numbers
  become `<S>1234</S>`, which is the convention the rest of the database uses and
  what the dictionary popup looks for; the `G`/`H` prefix and the morphology code
  are dropped. Footnote markers are dropped with them, matching how the
  translations from upstream read.
- `\uN?` escapes carry a code point plus an ANSI fallback character that has to
  be skipped, otherwise curly quotes come out as `?`.
- The interlinear keeps its Greek as Windows-1253 bytes in a second font, so
  those runs are decoded separately from the Spanish around them.
- Verses a given edition doesn't carry are stored as empty placeholders. They are
  left out entirely, the way bolls omits Matthew 17:21 from modern translations.
- e-Sword numbers the deuterocanonicals 67-73 straight after Revelation. The app
  numbers them 68-71 and 73-75, so they are remapped on the way in.

Verse ids are fixed per translation (the `id_base` column in `MODULES`) instead
of being assigned by the database. Bookmarks are saved by verse id, so the copy
in the database and the copy downloaded for offline reading have to agree, on
every machine. The bases sit above 100,000,000; upstream ids stop around 5.2M.

## Modules that can't be converted

`nblh.bblx` (Nueva Biblia Latinoamericana de Hoy) stores its verses as encrypted
blobs rather than text, so it isn't included.
