# Bible Viewer — Obsidian plugin

Embed [Bolls Bible](https://github.com/saulbravo/bain) in Obsidian’s right sidebar and copy selected verses or commentary into the active note.

## Features

- Bible app embedded in an iframe (right sidebar)
- Copy selected verses from the reader into the current note (markdown with bold references)
- Copy commentary paragraphs from the commentary modal into the active note (one blue `[!note]` callout with commentary title and verse reference)
- Configurable app URL (local Docker, TrueNAS, or public domain)

## Install from GitHub

### Manual

```bash
git clone https://github.com/saulbravo/bain.git
cd bain/obsidian-bible-viewer
# copy into your vault’s plugins folder:
cp -r . /path/to/your/vault/.obsidian/plugins/bible-viewer/
```

Or download this folder from GitHub and copy it to:

```text
YourVault/.obsidian/plugins/bible-viewer/
```

Required files: `manifest.json`, `main.js`, `styles.css`.

### BRAT (Beta Reviewers Auto Tester)

If this plugin is published as its own repository with these files at the repo root, add via BRAT using that repo URL.

When installed from the **bain** monorepo, use manual install (path above).

## Settings

| Setting | Default | Example |
|---------|---------|---------|
| **Bible App URL** | `https://bolls.familybravo.com` | `http://192.168.1.15:9080` for local LAN |

Enable the plugin under **Settings → Community plugins**.

## Usage

1. Open **Bible Viewer** (ribbon icon or command palette).
2. Have a markdown note open in the editor (insert goes into the active note).
3. **Verses:** enable verse copy/select mode, select verses, use the ← arrow to insert.
4. **Commentary:** open the commentary modal, select paragraph(s), use the ← arrow to insert.

**Requirements for commentary:** Bible app **v2.5+** (Docker tag `maxivious/bolls:v2.5` or newer) and plugin **v0.3.1+**. Multi-paragraph selections are merged into a single callout.

After updating the plugin on another device, copy the whole `bible-viewer` folder again (or pull latest from git) — `main.js` must include the `bible-commentary-selection` handler.

## Development

```bash
cd obsidian-bible-viewer
npm install
npm run build    # writes main.js
npm run dev      # watch mode
```

## Related

- Main app: [saulbravo/bain](https://github.com/saulbravo/bain)
- Docker / TrueNAS deploy: [docker/all-in-one/README.md](../docker/all-in-one/README.md)
