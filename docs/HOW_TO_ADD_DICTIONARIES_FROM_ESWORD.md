# Adding dictionaries from e-Sword modules

Every dictionary the upstream backup carries answers in English or Russian, so
the Spanish ones from e-Sword (`.dctx` files) are converted here and shipped with
the repo. The Strong's-keyed ones are the point: tapping a Hebrew or Greek word
in the reader looks its number up in whichever dictionary is selected.

## Building a module

```bash
python3 scripts/dctx_to_dictionary.py --modules-dir "~/Downloads/Instalador + módulos"
```

For every entry in that script's `MODULES` list this writes
`django/bolls/static/dictionaries/<ABBR>.zip` (the same zipped JSON the offline
downloader already serves), records what was built in
`dictionary-modules/dictionaries.json`, and adds the dictionary to
`imba/src/data/dictionaries.json`, which is the list the picker reads.

To see what the converter does with a single entry:

```bash
python3 scripts/dctx_to_dictionary.py --sample STRES H430
```

The abbreviation is what the URL and the saved preference use, and the column
holding it stops at eight characters.

## Loading it into the database

```bash
make load-dictionaries          # or: manage.py load_dictionary_modules
```

Like the translations, this imports anything the database doesn't have yet and
leaves the rest alone, so the all-in-one image runs it on every boot. `--replace`
reimports one that is already there, `--only ABBR` works on a single dictionary.

Searching needs the `unaccent` and `pg_trgm` extensions. The image creates them
while restoring the verse backup; a database that never went through that restore
needs them created by hand.

## What the converter does

Entries are RTF fragments, parsed with the same reader the Bible modules use
(`scripts/esword_rtf.py`).

- Hebrew and Greek headwords are stored as bytes in a legacy code page chosen by
  the font, so those runs are decoded as Windows-1255 and Windows-1253 rather
  than as text.
- Strong's entries lead with the word and its transliteration on their own lines,
  which is where `lexeme` and `transliteration` come from. Modules laid out
  differently keep the word inline, and only the headword is lifted out.
- Cross-references become `<a href=S:H433>H433</a>`, the form the reader turns
  into a tap of its own.
- The list of words the Reina-Valera used for a term becomes `short_definition`,
  which is what makes a search for a Spanish word find the Hebrew or Greek behind
  it.

Verse references inside definitions (`Gen_2:24`) are left as plain text. Linking
them would mean mapping each module's book abbreviations onto the app's book
numbers, and the text reads fine without it.

## Modules that can't be converted

`strong.dctx` stores its definitions as encrypted blobs rather than text, so it
isn't included. `strongspa.dctx` covers the same ground in Spanish.
