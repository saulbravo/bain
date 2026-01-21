# Building the Bible Viewer Plugin

The plugin needs to be built before it can be used in Obsidian. You need Node.js installed.

## Install Node.js

### On Fedora (your system):
```bash
sudo dnf install nodejs npm
```

### Or use Node Version Manager (nvm):
```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts
```

## Build the Plugin

Once Node.js is installed:

```bash
cd /home/maxivious/Documents/Bible/obsidian/Bible/.obsidian/plugins/bible-viewer
npm install
npm run build
```

This will create the `main.js` file that Obsidian needs.

## Enable in Obsidian

1. Open Obsidian
2. Go to Settings → Community plugins
3. Enable "Bible Viewer"
4. The Bible app should appear in the right sidebar


