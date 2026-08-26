import {
	App,
	Plugin,
	PluginSettingTab,
	Setting,
	WorkspaceLeaf,
	MarkdownView,
	Notice,
	ItemView,
	Editor,
	EditorPosition,
	TFile,
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
	lastMarkdownLeaf: WorkspaceLeaf | null = null;
	lastEditorCursor: { path: string; line: number; ch: number } | null = null;

	constructor(leaf: WorkspaceLeaf, plugin: BibleViewerPlugin) {
		super(leaf);
		this.plugin = plugin;
		this.messageHandler = this.handleMessage.bind(this);
	}

	snapshotMarkdownCursor(view: MarkdownView | null) {
		if (!view) {
			return;
		}
		this.lastMarkdownLeaf = view.leaf;
		try {
			const cursor = view.editor.getCursor();
			this.lastEditorCursor = {
				path: view.file?.path ?? "",
				line: cursor.line,
				ch: cursor.ch,
			};
		} catch {
			// Editor may not be ready yet.
		}
	}

	rememberMarkdownLeaf(leaf: WorkspaceLeaf | null) {
		if (leaf?.view instanceof MarkdownView) {
			this.snapshotMarkdownCursor(leaf.view);
		}
	}

	getMarkdownViewForInsert(): MarkdownView | null {
		const activeView = this.app.workspace.getActiveViewOfType(MarkdownView);
		if (activeView) {
			this.lastMarkdownLeaf = activeView.leaf;
			return activeView;
		}

		if (this.lastMarkdownLeaf?.view instanceof MarkdownView) {
			return this.lastMarkdownLeaf.view;
		}

		const markdownLeaves = this.app.workspace.getLeavesOfType("markdown");
		for (const leaf of markdownLeaves) {
			if (leaf.view instanceof MarkdownView) {
				this.lastMarkdownLeaf = leaf;
				return leaf.view;
			}
		}

		return null;
	}

	clampEditorPosition(editor: Editor, pos: { line: number; ch: number }): EditorPosition {
		const lastLine = Math.max(0, editor.lastLine());
		const line = Math.max(0, Math.min(pos.line, lastLine));
		const lineLength = editor.getLine(line)?.length ?? 0;
		const ch = Math.max(0, Math.min(pos.ch, lineLength));
		return { line, ch };
	}

	getInsertPosition(view: MarkdownView): EditorPosition {
		const editor = view.editor;
		const path = view.file?.path ?? "";
		const activeMarkdown = this.app.workspace.getActiveViewOfType(MarkdownView);
		if (activeMarkdown === view) {
			return editor.getCursor();
		}
		if (this.lastEditorCursor && this.lastEditorCursor.path === path) {
			return this.clampEditorPosition(editor, this.lastEditorCursor);
		}
		return { line: 0, ch: 0 };
	}

	positionAfterInsert(from: EditorPosition, text: string): EditorPosition {
		const lines = text.split("\n");
		return {
			line: from.line + lines.length - 1,
			ch: lines[lines.length - 1].length,
		};
	}

	isolateBlockText(editor: Editor, pos: EditorPosition, block: string): string {
		let text = block.replace(/\s+$/, "") + "\n\n";
		const line = editor.getLine(pos.line) ?? "";
		const atDocStart = pos.line === 0 && pos.ch === 0;
		const atLineStart = pos.ch === 0;

		if (!atLineStart) {
			text = (line.startsWith(">") ? "\n\n" : "\n") + text;
		} else if (!atDocStart) {
			const prevLine = editor.getLine(pos.line - 1) ?? "";
			if (prevLine.startsWith(">")) {
				text = "\n" + text;
			}
		}

		return text;
	}

	insertBlockIntoNote(view: MarkdownView, block: string) {
		const editor = view.editor;
		const from = this.getInsertPosition(view);
		const text = this.isolateBlockText(editor, from, block);
		editor.replaceRange(text, from);
		const end = this.positionAfterInsert(from, text);
		editor.setCursor(end);
		this.lastEditorCursor = {
			path: view.file?.path ?? "",
			line: end.line,
			ch: end.ch,
		};
		this.lastMarkdownLeaf = view.leaf;
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
		this.rememberMarkdownLeaf(this.app.workspace.activeLeaf);
		const openMarkdown = this.app.workspace.getActiveViewOfType(MarkdownView);
		if (openMarkdown) {
			this.snapshotMarkdownCursor(openMarkdown);
		}

		this.registerEvent(
			this.app.workspace.on("active-leaf-change", (leaf) => {
				this.rememberMarkdownLeaf(leaf);
			})
		);

		this.registerEvent(
			this.app.workspace.on("editor-change", (_editor, info) => {
				if (info instanceof MarkdownView) {
					this.snapshotMarkdownCursor(info);
				}
			})
		);

		this.registerDomEvent(document, "click", () => {
			const view = this.app.workspace.getActiveViewOfType(MarkdownView);
			if (view) {
				this.snapshotMarkdownCursor(view);
			}
		});

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
					sandbox: "allow-same-origin allow-scripts allow-forms allow-popups",
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
		} else if (event.data && event.data.type === "bible-commentary-selection") {
			console.log("Bible Viewer: Processing commentary selection", event.data);
			this.copyCommentaryToNote(event.data);
		} else if (event.data && event.data.type === "bible-dictionary-selection") {
			console.log("Bible Viewer: Processing dictionary selection", event.data);
			this.copyDictionaryToNote(event.data);
		} else if (event.data && event.data.type === "bible-open-note") {
			this.openNoteAtBlock(event.data.path, event.data.blockId);
		} else {
			console.log("Bible Viewer: Message type mismatch or no data", event.data);
		}
	}

	postToIframe(payload: Record<string, unknown>) {
		this.iframe?.contentWindow?.postMessage(payload, "*");
	}

	newBlockId(): string {
		const bytes = new Uint8Array(6);
		crypto.getRandomValues(bytes);
		return `bolls-${Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")}`;
	}

	sanitizeBlockId(id: string): string {
		const cleaned = String(id || "").replace(/[^A-Za-z0-9_-]/g, "").slice(0, 64);
		return cleaned || this.newBlockId();
	}

	async openNoteAtBlock(path?: string, blockId?: string) {
		if (!path) {
			new Notice("No note path to open.");
			this.reportLinkStatus(blockId, true);
			return;
		}

		const file = this.app.vault.getAbstractFileByPath(path);
		if (!(file instanceof TFile)) {
			new Notice(`Could not open note: ${path}`);
			this.reportLinkStatus(blockId, true);
			return;
		}

		let broken = false;
		if (blockId) {
			try {
				const content = await this.app.vault.cachedRead(file);
				broken = !content.includes(`^${blockId}`);
			} catch {
				broken = true;
			}
		}

		this.reportLinkStatus(blockId, broken);

		if (broken) {
			new Notice("That Bible passage is no longer in the note.");
			try {
				await this.app.workspace.openLinkText(path, path, false);
			} catch (error) {
				console.log("Bible Viewer: Failed to open note", error);
			}
			return;
		}

		const target = `${path}#^${blockId}`;
		try {
			await this.app.workspace.openLinkText(target, path, false);
		} catch (error) {
			console.log("Bible Viewer: Failed to open note", error);
			new Notice(`Could not open note: ${path}`);
			this.reportLinkStatus(blockId, true);
		}
	}

	reportLinkStatus(blockId: string | undefined, broken: boolean) {
		if (!blockId) {
			return;
		}
		this.postToIframe({
			type: "bible-note-link-status",
			blockId,
			broken,
		});
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
		blockId?: string;
		startVerse?: number;
		endVerse?: number;
	}) {
		const verses = data.verses;
		console.log("Bible Viewer: copyVersesToNote called with", data);
		console.log("Bible Viewer: Data keys:", Object.keys(data));
		console.log("Bible Viewer: Translation field:", data.translation);

		if (!verses || verses.length === 0) {
			new Notice("No verses selected to copy.");
			return;
		}
		
		const activeView = this.getMarkdownViewForInsert();
		
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
		const blockId = this.sanitizeBlockId(data.blockId || this.newBlockId());
		const formattedText = `${calloutHeader}\n${verseTexts}\n> ^${blockId}`;

		this.insertBlockIntoNote(activeView, formattedText);

		const file = activeView.file;
		if (file) {
			this.postToIframe({
				type: "bible-verse-linked",
				blockId,
				notePath: file.path,
				noteName: file.basename,
				vault: this.app.vault.getName(),
				translation: translationCode,
				bookId: Number(bookId),
				chapter: Number(chapter),
				startVerse: Number(data.startVerse || firstVerse.verse),
				endVerse: Number(data.endVerse || lastVerse.verse),
			});
		}

		new Notice(`Copied ${verses.length} verse${verses.length > 1 ? "s" : ""} to note`);
	}

	copyCommentaryToNote(data: {
		sections: Array<{
			reference: string;
			text: string;
			verse: number;
		}>;
		commentaryTitle?: string;
		reference?: string;
		translation?: string;
		book?: string;
		chapter?: number;
		bookId?: number | string;
	}) {
		const sections = data.sections || [];
		if (sections.length === 0) {
			new Notice("No commentary to copy.");
			return;
		}

		const activeView = this.getMarkdownViewForInsert();
		if (!activeView) {
			new Notice("No active note to copy commentary to.");
			return;
		}

		const translationCode = data?.translation || "BBE";
		const bookId = data.bookId || 1;
		const chapter = data.chapter || 1;
		const verse = sections[0]?.verse || 1;
		const title = data.commentaryTitle || "Comentario Bíblico Adventista";
		const reference =
			data.reference || sections[0]?.reference || `${data.book || "Genesis"} ${chapter}:${verse}`;
		const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verse}`;

		const body = sections
			.map((section) => section.text.trim())
			.filter((text) => text.length > 0)
			.map((text) =>
				text
					.split(/\n+/)
					.filter((line) => line.trim().length > 0)
					.map((line) => `> ${line.trim()}`)
					.join("\n")
			)
			.join("\n>\n");

		const calloutHeader = `> [!note] [${title}](${url})`;
		const subtitleLine = `> ${reference}`;
		const formattedText = `${calloutHeader}\n${subtitleLine}\n${body}`;

		this.insertBlockIntoNote(activeView, formattedText);

		new Notice(`Copied commentary to note`);
	}

	copyDictionaryToNote(data: {
		dictionary?: string;
		dictionaryName?: string;
		query?: string;
		topic?: string;
		heading?: string;
		definition?: string;
		translation?: string;
		book?: string;
		chapter?: number;
		bookId?: number | string;
		verse?: number;
	}) {
		const definition = String(data.definition || "").trim();
		if (!definition) {
			new Notice("No dictionary entry to copy.");
			return;
		}

		const activeView = this.getMarkdownViewForInsert();
		if (!activeView) {
			new Notice("No active note to copy dictionary entry to.");
			return;
		}

		const translationCode = data?.translation || "BBE";
		const bookId = data.bookId || 1;
		const chapter = data.chapter || 1;
		const verse = data.verse || 1;
		const dictionaryCode = data.dictionary || "";
		const topic = data.topic || data.query || "";
		const titleBits = [dictionaryCode, topic].filter((bit) => bit && String(bit).trim().length > 0);
		const title = titleBits.join(" · ") || data.dictionaryName || "Dictionary";
		const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verse}`;

		const body = definition
			.split(/\n+/)
			.filter((line) => line.trim().length > 0)
			.map((line) => `> ${line.trim()}`)
			.join("\n");

		const calloutHeader = `> [!dictionary] [${title}](${url})`;
		const heading = String(data.heading || "").trim();
		const formattedText = heading
			? `${calloutHeader}\n> ${heading}\n${body}`
			: `${calloutHeader}\n${body}`;

		this.insertBlockIntoNote(activeView, formattedText);

		new Notice("Copied dictionary entry to note");
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

