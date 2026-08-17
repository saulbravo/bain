# Bible Viewer — Obsidian plugin

Embed [Bolls Bible](https://github.com/saulbravo/bain) in Obsidian’s right sidebar and copy selected verses into the active note.

## Features

- Bible app embedded in an iframe (right sidebar)
- Copy selected verses from the reader into the current note (markdown with bold references)
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
| **Bible App URL** | `http://localhost:8080` | `https://bolls.familybravo.com` |

Enable the plugin under **Settings → Community plugins**.

## Usage

1. Open **Bible Viewer** (ribbon icon or command palette).
2. In the embedded reader, enable verse copy/select mode.
3. Select verses and use the arrow control to insert them into your note.

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
