Commentaries reach the app in two different ways.

# 1. Standalone commentaries (the picker in the verse commentary modal)

These are e-Sword modules, a single `.cmtx` SQLite file per commentary. To add one,
drop the file into `commentary-modules/` and rebuild the image. Nothing else is
needed: Django scans that folder at startup, reads the title out of each module's
`Details` table, and the tab strip at the bottom of the modal header lists
whatever it finds. The pencil next to the close button hides tabs you don't want;
CBA and EGW lead the strip and can't be hidden.

The id used in the URL and in the saved preference comes from the module's
abbreviation, so `NVI.cmtx` is served from `/get-commentary/nvi/43/3/16/`. The
Adventist commentary keeps the fixed id `cba` and always sorts first.

Tab labels come from `short`, which trims the module's abbreviation (quotes,
trailing periods, parentheticals). When that still reads badly, add an entry to
`SHORT_NAME_OVERRIDES` in `django/bolls/utils/commentaries.py`.

Endpoints:

- `GET /get-commentaries/` lists `{id, name, abbreviation, short}` for every module found.
- `GET /get-commentary/<id>/<book>/<chapter>/<verse>/` returns the commentary text.
  An unknown id falls back to the Adventist commentary.

`COMMENTARY_MODULES_DIR` overrides the folder (the all-in-one image sets it in
`docker/all-in-one/entrypoint.sh`). `CBA_COMMENTARY_PATH` still points at the
Adventist file on its own, which is how it was shipped before this folder existed.

Book numbering inside the modules is the usual 1-66, matching the app's, so no
remapping is required.

# 2. Translator footnotes attached to a Bible translation (the `†` marks)

These live in the `bolls_commentary` table and are keyed by translation
abbreviation. The instructions below are oriented on MyBible modules.

First of all run script from `commentaries_concordance.sql` in the commentaries database shipped with MyBible module, something like `KB.commentaries.SQLite3`.

Then export `commentaries` table into a `mybcommentaries.csv` file.

Optionally there might be cross references file `ABBR.crossreferences.SQLite3`, run the script from `references_concordance.sql` in the cross references database. Then export `cross_references` table into a `cross_references.csv` file. If you use cross references you should update `books_short_names` variable at the books_map.py file.

Once all data in place -- update translation variable at `main.py`, comment out the `convert_cross_references_into_links` code call if you don't have cross references, and run it. Have fun!
