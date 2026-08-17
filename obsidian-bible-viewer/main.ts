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
	bibleAppUrl: "https://bolls.familybravo.com",
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

		this.addCommand({
			id: "open-bible-login",
			name: "Open Bolls login in browser",
			callback: () => {
				window.open(`${this.settings.bibleAppUrl}/accounts/login/`, "_blank");
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
		// Migrate legacy default saved in Obsidian data
		if (
			this.settings.bibleAppUrl === "http://localhost:8080" ||
			this.settings.bibleAppUrl === "http://127.0.0.1:8080"
		) {
			this.settings.bibleAppUrl = DEFAULT_SETTINGS.bibleAppUrl;
			await this.saveSettings();
		}
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
				sandbox: "allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox",
			},
		});

		// Set src after a tiny delay to ensure iframe is ready
		setTimeout(() => {
			if (this.iframe) {
				this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
				console.log("Bible Viewer: Iframe src set with cache-buster:", cacheBuster);
				
				// When iframe loads, try to clear its cache (only once, not on every load)
				let cacheCleared = false;
				this.iframe.onload = () => {
					// Only send cache clear message once per iframe instance
					if (cacheCleared) {
						return;
					}
					cacheCleared = true;
					
					// Wait a bit for iframe to fully initialize
					setTimeout(() => {
						try {
							const iframeWindow = this.iframe?.contentWindow;
							if (iframeWindow) {
								// Send message to iframe to clear service worker cache (only once)
								iframeWindow.postMessage({ type: 'clear-cache', force: true, timestamp: Date.now() }, '*');
								console.log("Bible Viewer: Sent clear-cache message to iframe");
								
								// Also try to unregister service worker via postMessage
								iframeWindow.postMessage({ type: 'unregister-sw', force: true, timestamp: Date.now() }, '*');
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
					sandbox: "allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox",
				},
			});
			
			// Set src after a tiny delay to ensure iframe is ready
			setTimeout(() => {
				if (this.iframe) {
					this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
			console.log("Bible Viewer: Iframe recreated with cache-buster:", cacheBuster);
					
					// When iframe loads, try to clear its cache (only once per refresh)
					let cacheCleared = false;
					this.iframe.onload = () => {
						// Only send cache clear message once per iframe instance
						if (cacheCleared) {
							return;
						}
						cacheCleared = true;
						
						// Wait a bit for iframe to fully initialize
						setTimeout(() => {
							try {
								const iframeWindow = this.iframe?.contentWindow;
								if (iframeWindow) {
									// Send message to iframe to clear service worker cache (only once)
									iframeWindow.postMessage({ type: 'clear-cache', force: true, timestamp: Date.now() }, '*');
									console.log("Bible Viewer: Sent clear-cache message to iframe after refresh");
									
									// Also try to unregister service worker via postMessage
									iframeWindow.postMessage({ type: 'unregister-sw', force: true, timestamp: Date.now() }, '*');
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

	isAllowedMessageOrigin(origin: string): boolean {
		if (origin === "null" || origin === window.location.origin) {
			return true;
		}
		if (origin.includes("localhost") || origin.includes("127.0.0.1")) {
			return true;
		}
		try {
			return new URL(origin).origin === new URL(this.plugin.settings.bibleAppUrl).origin;
		} catch {
			return false;
		}
	}

	handleMessage(event: MessageEvent) {
		// Debug logging
		console.log("Bible Viewer: Received message", {
			origin: event.origin,
			data: event.data,
			dataType: typeof event.data,
			dataKeys: event.data ? Object.keys(event.data) : [],
			source: event.source
		});
		
		const fromIframe = event.source === this.iframe?.contentWindow;
		if (!this.isAllowedMessageOrigin(event.origin) && !fromIframe) {
			console.log("Bible Viewer: Rejected message from origin", event.origin);
			return;
		}

		if (event.data && event.data.type === "bible-verse-selection") {
			console.log("Bible Viewer: Processing verse selection", event.data);
			console.log("Bible Viewer: Translation in data:", event.data.translation);
			this.copyVersesToNote(event.data);
		} else {
			console.log("Bible Viewer: Message type mismatch or no data", event.data);
		}
	}

	copyVersesToNote(data: {
		verses: Array<{
		reference: string;
		text: string;
		verse: number;
		}>;
		translation?: string;
		translationFullName?: string;
		book?: string;
		chapter?: number;
		bookId?: number | string;
	}) {
		const verses = data.verses;
		console.log("Bible Viewer: copyVersesToNote called with", data);
		console.log("Bible Viewer: Data keys:", Object.keys(data));
		console.log("Bible Viewer: Translation field:", data.translation);
		
		const activeView =
			this.app.workspace.getActiveViewOfType(MarkdownView);
		
		if (!activeView) {
			console.log("Bible Viewer: No active markdown view");
			new Notice("No active note to copy verses to.");
			return;
		}
		
		console.log("Bible Viewer: Active view found", activeView);

		// Build reference string
		const firstVerse = verses[0];
		const lastVerse = verses[verses.length - 1];
		let referenceText: string;
		
		if (verses.length === 1) {
			referenceText = firstVerse.reference;
		} else {
			// Multiple verses: "Genesis 1:2-3" or "Genesis 1:2"
			if (firstVerse.verse === lastVerse.verse) {
				referenceText = firstVerse.reference;
			} else {
				referenceText = `${firstVerse.reference}-${lastVerse.verse}`;
			}
		}

		// Get translation code (abbreviation like YLT, KJV, etc.)
		console.log("Bible Viewer: Full data object received:", JSON.stringify(data, null, 2));
		console.log("Bible Viewer: data.translation value:", data.translation);
		console.log("Bible Viewer: All data keys:", Object.keys(data || {}));
		
		const translationCode = data?.translation || "BBE";
		console.log("Bible Viewer: Using translation code:", translationCode);
		
		// Build localhost URL
		// Format: http://localhost:8080/{translation}/{bookId}/{chapter}/{verseRange}
		const bookId = data.bookId || 1; // Default to 1 if not provided
		const chapter = data.chapter || 1;
		
		// Build verse range: single verse is just the number, multiple verses use range format
		let verseRange: string;
		if (verses.length === 1) {
			verseRange = `${firstVerse.verse}`;
		} else {
			verseRange = `${firstVerse.verse}-${lastVerse.verse}`;
		}
		
		const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verseRange}`;
		
		// Format as callout (matching Bible Reference plugin format)
		// > [!bible] [Reference - Translation Code](url)
		// > verse text
		const calloutHeader = `> [!bible] [${referenceText} - ${translationCode}](${url})`;
		const verseTexts = verses.map((v) => `> ${v.verse}. ${v.text}`).join("\n");
		const formattedText = `${calloutHeader}\n${verseTexts}\n\n`;

		// Insert at cursor position
		const editor = activeView.editor;
		const cursor = editor.getCursor();
		editor.replaceRange(formattedText, cursor);

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
			.setDesc("URL of the Bible app (default: https://bolls.familybravo.com)")
			.addText((text) =>
				text
					.setPlaceholder("https://bolls.familybravo.com")
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

