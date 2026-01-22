import {
	App,
	Plugin,
	PluginSettingTab,
	Setting,
	WorkspaceLeaf,
	MarkdownView,
	Notice,
	ItemView,
} from "obsidian";

interface BibleViewerSettings {
	bibleAppUrl: string;
}

const DEFAULT_SETTINGS: BibleViewerSettings = {
	bibleAppUrl: "http://localhost:8080",
};

export default class BibleViewerPlugin extends Plugin {
	settings: BibleViewerSettings;
	bibleView: BibleView;

	async onload() {
		await this.loadSettings();

		// Register the view
		this.registerView(
			"bible-viewer",
			(leaf) => (this.bibleView = new BibleView(leaf, this))
		);

		// Add command to open Bible viewer
		this.addCommand({
			id: "open-bible-viewer",
			name: "Open Bible Viewer",
			callback: () => {
				this.activateView();
			},
		});

		// Add ribbon icon
		this.addRibbonIcon("book-open", "Open Bible Viewer", () => {
			this.activateView();
		});

		// Add settings tab
		this.addSettingTab(new BibleViewerSettingTab(this.app, this));

		// Automatically open the view in the right leaf
		this.app.workspace.onLayoutReady(() => {
			this.activateView();
		});
	}

	onunload() {
		this.app.workspace.detachLeavesOfType("bible-viewer");
	}

	async loadSettings() {
		this.settings = Object.assign(
			{},
			DEFAULT_SETTINGS,
			await this.loadData()
		);
	}

	async saveSettings() {
		await this.saveData(this.settings);
	}

	async activateView() {
		const { workspace } = this.app;

		let leaf: WorkspaceLeaf | null = null;
		const leaves = workspace.getLeavesOfType("bible-viewer");

		if (leaves.length > 0) {
			// Reuse existing leaf
			leaf = leaves[0];
		} else {
			// Create new leaf in right sidebar
			leaf = workspace.getRightLeaf(false);
			await leaf.setViewState({
				type: "bible-viewer",
				active: true,
			});
		}

		workspace.revealLeaf(leaf);
	}
}

class BibleView extends ItemView {
	plugin: BibleViewerPlugin;
	iframe: HTMLIFrameElement;
	messageHandler: (event: MessageEvent) => void;

	constructor(leaf: WorkspaceLeaf, plugin: BibleViewerPlugin) {
		super(leaf);
		this.plugin = plugin;
		this.messageHandler = this.handleMessage.bind(this);
	}

	getViewType() {
		return "bible-viewer";
	}

	getDisplayText() {
		return "Bible Viewer";
	}

	getIcon() {
		return "book-open";
	}

	async onOpen() {
		const container = this.containerEl.children[1];
		container.empty();
		container.addClass("bible-viewer-container");

		// Create iframe with aggressive cache-busting parameter
		// Use multiple parameters to bypass all caching layers
		const timestamp = Date.now();
		const random = Math.random().toString(36).substring(7);
		const cacheBuster = `?v=${timestamp}&_nocache=1&_refresh=${random}&_t=${timestamp}&_r=${random}&sw=bypass&_cb=${timestamp}${random}`;
		
		// Create iframe element first
		this.iframe = container.createEl("iframe", {
			cls: "bible-viewer-iframe",
			attr: {
				sandbox: "allow-same-origin allow-scripts allow-forms allow-popups",
			},
		});

		// Set src after a tiny delay to ensure iframe is ready
		setTimeout(() => {
			if (this.iframe) {
				this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
				console.log("Bible Viewer: Iframe src set with cache-buster:", cacheBuster);
				
				// When iframe loads, try to clear its cache
				this.iframe.onload = () => {
					// Wait a bit for iframe to fully initialize
					setTimeout(() => {
						try {
							const iframeWindow = this.iframe?.contentWindow;
							if (iframeWindow) {
								// Send message to iframe to clear service worker cache
								iframeWindow.postMessage({ type: 'clear-cache', force: true }, '*');
								console.log("Bible Viewer: Sent clear-cache message to iframe");
								
								// Also try to unregister service worker via postMessage
								iframeWindow.postMessage({ type: 'unregister-sw', force: true }, '*');
							}
						} catch (e) {
							// Cross-origin restrictions might prevent this
							console.log("Bible Viewer: Could not access iframe window (expected if cross-origin)");
						}
					}, 500);
				};
			}
		}, 10);

		// Listen for messages from the iframe
		window.addEventListener("message", this.messageHandler);
		console.log("Bible Viewer: Message listener added, iframe loaded with cache-buster:", cacheBuster);
	}

	async onload() {
		// Refresh iframe when view is loaded/reopened
		if (this.iframe) {
			this.refreshIframe();
		}
	}

	async onClose() {
		if (this.messageHandler) {
			window.removeEventListener("message", this.messageHandler);
			console.log("Bible Viewer: Message listener removed");
		}
	}

	refreshIframe() {
		// Force reload iframe with aggressive cache-busting parameter
		if (this.iframe) {
			const timestamp = Date.now();
			const random = Math.random().toString(36).substring(7);
			const cacheBuster = `?v=${timestamp}&_nocache=1&_refresh=${random}&_t=${timestamp}&_r=${random}&sw=bypass&_force=1&_cb=${timestamp}${random}`;
			
			// Remove iframe and recreate to force fresh load
			const oldIframe = this.iframe;
			const container = oldIframe.parentElement;
			oldIframe.remove();
			
			// Create new iframe
			this.iframe = container.createEl("iframe", {
				cls: "bible-viewer-iframe",
				attr: {
					sandbox: "allow-same-origin allow-scripts allow-forms allow-popups",
				},
			});
			
			// Set src after a tiny delay to ensure iframe is ready
			setTimeout(() => {
				if (this.iframe) {
					this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
					console.log("Bible Viewer: Iframe recreated with cache-buster:", cacheBuster);
					
					// When iframe loads, try to clear its cache
					this.iframe.onload = () => {
						// Wait a bit for iframe to fully initialize
						setTimeout(() => {
							try {
								const iframeWindow = this.iframe?.contentWindow;
								if (iframeWindow) {
									// Send message to iframe to clear service worker cache
									iframeWindow.postMessage({ type: 'clear-cache', force: true }, '*');
									console.log("Bible Viewer: Sent clear-cache message to iframe after refresh");
									
									// Also try to unregister service worker via postMessage
									iframeWindow.postMessage({ type: 'unregister-sw', force: true }, '*');
								}
							} catch (e) {
								// Cross-origin restrictions might prevent this
								console.log("Bible Viewer: Could not access iframe window (expected if cross-origin)");
							}
						}, 500);
					};
				}
			}, 10);
		}
	}

	handleMessage(event: MessageEvent) {
		// Debug logging
		console.log("Bible Viewer: Received message", {
			origin: event.origin,
			data: event.data,
			source: event.source
		});
		
		// Only accept messages from the Bible app (localhost or 127.0.0.1, with or without port)
		// Also accept messages from the iframe itself
		const isLocalhost = event.origin.includes("localhost") || 
		                   event.origin.includes("127.0.0.1") ||
		                   event.origin === "null" || // Some browsers use "null" for same-origin
		                   event.source === this.iframe?.contentWindow;
		
		if (!isLocalhost) {
			console.log("Bible Viewer: Rejected message from origin", event.origin);
			return;
		}

		if (event.data && event.data.type === "bible-verse-selection") {
			console.log("Bible Viewer: Processing verse selection", event.data.verses);
			this.copyVersesToNote(event.data.verses);
		} else {
			console.log("Bible Viewer: Message type mismatch or no data", event.data);
		}
	}

	copyVersesToNote(verses: Array<{
		reference: string;
		text: string;
		verse: number;
	}>) {
		console.log("Bible Viewer: copyVersesToNote called with", verses);
		
		const activeView =
			this.app.workspace.getActiveViewOfType(MarkdownView);
		
		if (!activeView) {
			console.log("Bible Viewer: No active markdown view");
			new Notice("No active note to copy verses to.");
			return;
		}
		
		console.log("Bible Viewer: Active view found", activeView);

		// Format verses for markdown
		let formattedText = "";
		
		if (verses.length === 1) {
			// Single verse: "John 3:16 For God so loved the world..."
			formattedText = `**${verses[0].reference}** ${verses[0].text}`;
		} else {
			// Multiple verses: "John 3:16-17 For God so loved the world... that whoever believes..."
			const firstVerse = verses[0];
			const lastVerse = verses[verses.length - 1];
			const reference =
				firstVerse.verse === lastVerse.verse
					? firstVerse.reference
					: `${firstVerse.reference}-${lastVerse.verse}`;
			
			const verseTexts = verses.map((v) => v.text).join(" ");
			formattedText = `**${reference}** ${verseTexts}`;
		}

		// Insert at cursor position
		const editor = activeView.editor;
		const cursor = editor.getCursor();
		editor.replaceRange(formattedText + "\n\n", cursor);

		new Notice(`Copied ${verses.length} verse${verses.length > 1 ? "s" : ""} to note`);
	}
}

class BibleViewerSettingTab extends PluginSettingTab {
	plugin: BibleViewerPlugin;

	constructor(app: App, plugin: BibleViewerPlugin) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display(): void {
		const { containerEl } = this;

		containerEl.empty();

		containerEl.createEl("h2", { text: "Bible Viewer Settings" });

		new Setting(containerEl)
			.setName("Bible App URL")
			.setDesc("URL of the Bible app (default: http://localhost:8080)")
			.addText((text) =>
				text
					.setPlaceholder("http://localhost:8080")
					.setValue(this.plugin.settings.bibleAppUrl)
					.onChange(async (value) => {
						this.plugin.settings.bibleAppUrl = value;
						await this.plugin.saveSettings();
						// Reload iframe if view is open with cache-busting
						if (this.plugin.bibleView) {
							const cacheBuster = `?v=${Date.now()}&_nocache=1&_refresh=${Math.random()}`;
							this.plugin.bibleView.refreshIframe();
						}
					})
			);
	}
}

