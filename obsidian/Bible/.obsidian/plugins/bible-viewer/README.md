# Bible Viewer Plugin for Obsidian

This plugin embeds the Bible app in the right sidebar pane of Obsidian and allows you to copy selected verses directly into your current note.

## Features

- **Hybrid Embed**: The Bible app is embedded in an iframe in the right sidebar
- **Verse Copy Select**: When verse copy select mode is enabled in the Bible app and verses are selected, click the left arrow button to copy them to your current Obsidian note
- **Automatic Formatting**: Verses are automatically formatted as markdown with bold references

## Installation

1. Make sure the Bible app is running at `http://localhost:8080` (or configure a different URL in settings)
2. In Obsidian, go to Settings → Community plugins → Browse and search for "Bible Viewer", or manually install from this folder
3. Enable the plugin
4. The Bible viewer will automatically open in the right sidebar

## Usage

1. Open the Bible app in the right sidebar (it should open automatically when the plugin is enabled)
2. Navigate to any book, chapter, and verse
3. Enable "Verse Copy Select" mode in the Bible app (look for the copy select button/toggle)
4. Select one or more verses by clicking on them
5. Use the handles to extend the selection if needed
6. Click the left arrow button (←) in the selection box to copy the verses to your current Obsidian note

## Settings

- **Bible App URL**: Configure the URL where your Bible app is running (default: `http://localhost:8080`)

## Development

### Building the Plugin

The plugin needs to be built before it can be used in Obsidian. You have two options:

#### Option 1: Using npm (if you have Node.js installed)

```bash
cd /home/maxivious/Documents/Bible/obsidian/Bible/.obsidian/plugins/bible-viewer
npm install
npm run build
```

This will create the `main.js` file that Obsidian needs.

#### Option 2: Using Obsidian's Hot Reload Plugin

1. Install the "Hot Reload" plugin in Obsidian
2. The plugin will automatically compile TypeScript files when you save them

### File Structure

- `main.ts` - Main plugin code
- `manifest.json` - Plugin metadata
- `styles.css` - Plugin styles
- `package.json` - Dependencies
- `tsconfig.json` - TypeScript configuration
- `esbuild.config.mjs` - Build configuration

### How It Works

1. The plugin creates an iframe in the right sidebar that loads the Bible app
2. When verse copy select mode is enabled and verses are selected, the Bible app sends a `postMessage` to the parent window
3. The plugin listens for these messages and copies the formatted verses to the current note

## Troubleshooting

### Translation Code Not Showing

If verses are being inserted with "BBE" instead of the actual translation code (YLT, KJV, etc.), see `FIX_TRANSLATION_CODE_ISSUE.md` for details on the fix and why it was needed.

The issue was related to how `postMessage` serializes objects - reactive/observable properties from Imba weren't being properly serialized. The fix ensures all properties are converted to plain JavaScript primitives before sending.

