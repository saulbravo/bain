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
	addIcon,
	setIcon,
} from "obsidian";
import { RangeSetBuilder } from "@codemirror/state";
import { Decoration, DecorationSet, EditorView, ViewPlugin, ViewUpdate } from "@codemirror/view";
import { decorateVerseRefs, findVerseRefs, parseBibleAppLink, verseHitFromEl, VerseHit } from "./verse-refs";

type PaneWidthMode = "half" | "full";

interface BibleViewerSettings {
	bibleAppUrl: string;
	detectVerseReferences: boolean;
	openBibleLinksInViewer: boolean;
	lastTranslation: string;
	paneWidthMode: PaneWidthMode;
}

const DEFAULT_SETTINGS: BibleViewerSettings = {
	bibleAppUrl: "https://bolls.familybravo.com",
	detectVerseReferences: true,
	openBibleLinksInViewer: true,
	lastTranslation: "",
	paneWidthMode: "half",
};

const HALF_WIDTH_ICON_ID = "bible-viewer-half";
// Same lucide book-open paths Obsidian uses; right page is closed and filled.
const HALF_WIDTH_ICON_SVG = `<path d="M12 7v14"/><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4"/><path fill="currentColor" stroke="currentColor" d="M21 18a1 1 0 0 0 1-1V4a1 1 0 0 0-1-1h-5a4 4 0 0 0-4 4v11z"/>`;

export default class BibleViewerPlugin extends Plugin {
	settings: BibleViewerSettings;
	bibleView: BibleView;
	ribbonEl: HTMLElement | null = null;

	async onload() {
		await this.loadSettings();
		try {
			addIcon(HALF_WIDTH_ICON_ID, HALF_WIDTH_ICON_SVG);
		} catch {
			// Custom icon is optional; plugin must still load.
		}

		// Register the view
		this.registerView(
			"bible-viewer",
			(leaf) => (this.bibleView = new BibleView(leaf, this))
		);

		this.addCommand({
			id: "open-bible-viewer",
			name: "Open Bible Viewer",
			callback: () => {
				void this.activateView();
			},
		});

		this.addCommand({
			id: "toggle-bible-viewer-width",
			name: "Toggle Bible Viewer pane width",
			callback: () => {
				void this.togglePaneWidth();
			},
		});

		this.ribbonEl = this.addRibbonIcon("book-open", this.ribbonLabel(), () => {
			void this.handleRibbonClick();
		});
		this.syncRibbonIcon();

		// Add settings tab
		this.addSettingTab(new BibleViewerSettingTab(this.app, this));

		this.registerMarkdownPostProcessor((el) => {
			if (!this.settings.detectVerseReferences) {
				return;
			}
			decorateVerseRefs(el);
		});

		this.registerEditorExtension(createVerseRefExtension(this));

		this.registerDomEvent(
			document,
			"click",
			(event: MouseEvent) => {
				if (event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) {
					return;
				}
				const target = event.target as HTMLElement | null;
				if (this.settings.openBibleLinksInViewer) {
					const link = target?.closest?.("a");
					if (link) {
						const href = link.getAttribute("href") || link.getAttribute("data-href") || "";
						const hit = parseBibleAppLink(href, link.textContent || "", this.settings.bibleAppUrl);
						if (hit) {
							event.preventDefault();
							event.stopPropagation();
							void this.openVerseReference(hit);
							return;
						}
					}
				}
				if (!this.settings.detectVerseReferences) {
					return;
				}
				const el = target?.closest?.(".bible-verse-ref");
				if (!el) {
					return;
				}
				const hit = verseHitFromEl(el);
				if (!hit) {
					return;
				}
				event.preventDefault();
				event.stopPropagation();
				void this.openVerseReference(hit);
			},
			true
		);

		this.registerDomEvent(window, "resize", () => {
			window.requestAnimationFrame(() => {
				try {
					this.applyPaneWidth(this.settings.paneWidthMode);
				} catch {
					// Ignore resize failures on platforms without a sidedock size API.
				}
			});
		});

		// Automatically open the view in the right leaf and restore last half/full size
		this.app.workspace.onLayoutReady(() => {
			void this.activateView(true);
		});
	}

	async openVerseReference(hit: VerseHit) {
		await this.activateView();
		const view = this.bibleView;
		if (!view) {
			new Notice("Bible Viewer is not open.");
			return;
		}
		view.navigateToVerse(hit);
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
		if (this.settings.paneWidthMode !== "full" && this.settings.paneWidthMode !== "half") {
			this.settings.paneWidthMode = "half";
		}
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

	ribbonIconId(): string {
		return this.settings.paneWidthMode === "half" ? HALF_WIDTH_ICON_ID : "book-open";
	}

	ribbonLabel(): string {
		return this.settings.paneWidthMode === "full"
			? "Bible Viewer: full width (click for half)"
			: "Bible Viewer: half width (click for full)";
	}

	syncRibbonIcon() {
		const iconId = this.ribbonIconId();
		const half = this.settings.paneWidthMode === "half";
		if (this.ribbonEl) {
			this.ribbonEl.setAttribute("aria-label", this.ribbonLabel());
			this.ribbonEl.setAttribute("title", this.ribbonLabel());
			this.ribbonEl.classList.toggle("bible-viewer-half", half);
			try {
				setIcon(this.ribbonEl, iconId);
			} catch {
				setIcon(this.ribbonEl, "book-open");
			}
		}
		const tabIcon = (this.bibleView?.leaf as { tabHeaderInnerIconEl?: HTMLElement } | undefined)?.tabHeaderInnerIconEl;
		if (tabIcon) {
			tabIcon.classList.toggle("bible-viewer-half", half);
			try {
				setIcon(tabIcon, iconId);
			} catch {
				setIcon(tabIcon, "book-open");
			}
		}
	}

	async handleRibbonClick() {
		await this.togglePaneWidth();
	}

	workspaceWidth(): number {
		const el = this.app.workspace.containerEl;
		return el?.clientWidth || window.innerWidth;
	}

	sideDockSize(dock: { collapsed?: boolean; containerEl?: HTMLElement } | null): number {
		if (!dock || dock.collapsed) {
			return 0;
		}
		return dock.containerEl?.clientWidth || 0;
	}

	paneWidthPx(mode: PaneWidthMode): number {
		const workspace = this.app.workspace as App["workspace"] & {
			leftSplit?: { collapsed?: boolean; containerEl?: HTMLElement };
		};
		const total = this.workspaceWidth();
		const left = this.sideDockSize(workspace.leftSplit || null);
		const available = Math.max(320, total - left);
		return mode === "full"
			? Math.max(available - 48, Math.round(available * 0.92))
			: Math.round(available * 0.5);
	}

	setSplitWidth(split: {
		collapsed?: boolean;
		expand?: () => void;
		setSize?: (size: number) => void;
		size?: number;
		containerEl?: HTMLElement;
	} | null, size: number) {
		if (!split) {
			return;
		}
		if (split.collapsed && typeof split.expand === "function") {
			split.expand();
		}
		if (typeof split.setSize === "function") {
			split.setSize(size);
		}
		split.size = size;
		const el = split.containerEl;
		if (el) {
			el.style.setProperty("width", `${size}px`);
			el.style.setProperty("max-width", `${size}px`);
			el.style.flexBasis = `${size}px`;
		}
	}

	applyPaneWidth(mode: PaneWidthMode) {
		const workspace = this.app.workspace as App["workspace"] & {
			rightSplit?: {
				collapsed?: boolean;
				expand?: () => void;
				setSize?: (size: number) => void;
				size?: number;
				containerEl?: HTMLElement;
			};
			requestResize?: () => void;
		};
		const size = this.paneWidthPx(mode);
		this.setSplitWidth(workspace.rightSplit || null, size);

		const rightEl =
			workspace.rightSplit?.containerEl ||
			(this.app.workspace.containerEl.querySelector(".workspace-split.mod-right-split") as HTMLElement | null) ||
			(this.app.workspace.containerEl.querySelector(".workspace-drawer.mod-right") as HTMLElement | null);
		if (rightEl) {
			rightEl.style.setProperty("width", `${size}px`);
			rightEl.style.setProperty("max-width", `${size}px`);
			rightEl.style.flexBasis = `${size}px`;
		}

		workspace.requestResize?.();
		try {
			void workspace.requestSaveLayout();
		} catch {
			// Older Obsidian builds expose this as a debouncer; ignore if it isn't callable.
		}
		this.syncRibbonIcon();
	}

	async togglePaneWidth() {
		await this.activateView(false);
		this.settings.paneWidthMode = this.settings.paneWidthMode === "full" ? "half" : "full";
		await this.saveSettings();
		this.applyPaneWidth(this.settings.paneWidthMode);
		window.setTimeout(() => this.applyPaneWidth(this.settings.paneWidthMode), 50);
		window.setTimeout(() => this.applyPaneWidth(this.settings.paneWidthMode), 200);
	}

	async activateView(applyWidth = true) {
		const { workspace } = this.app;

		let leaf: WorkspaceLeaf | null = null;
		const leaves = workspace.getLeavesOfType("bible-viewer");

		if (leaves.length > 0) {
			leaf = leaves[0];
		} else {
			leaf = workspace.getRightLeaf(false);
			if (!leaf) {
				return;
			}
			await leaf.setViewState({
				type: "bible-viewer",
				active: true,
			});
		}

		workspace.revealLeaf(leaf);
		if (applyWidth) {
			window.requestAnimationFrame(() => this.applyPaneWidth(this.settings.paneWidthMode));
			window.setTimeout(() => this.applyPaneWidth(this.settings.paneWidthMode), 50);
		}
	}
}

class BibleView extends ItemView {
	plugin: BibleViewerPlugin;
	iframe: HTMLIFrameElement;
	messageHandler: (event: MessageEvent) => void;
	lastMarkdownLeaf: WorkspaceLeaf | null = null;
	lastEditorCursor: { path: string; line: number; ch: number } | null = null;
	pendingNavigation: string | null = null;

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

	forceBlackHighlightText(html: string): string {
		if (!html) {
			return html || "";
		}
		const black = "color: #000; -webkit-text-fill-color: #000;";
		return html.replace(/<(mark|span)(\s[^>]*?)?>/gi, (tag, name: string, attrs = "") => {
			const isMark = name.toLowerCase() === "mark";
			const hasFill = /background(-color)?\s*:/i.test(attrs);
			if (!isMark && !hasFill) {
				return tag;
			}
			if (/style\s*=/i.test(attrs)) {
				return `<${name}${attrs.replace(/style\s*=\s*(["'])([\s\S]*?)\1/i, (_m, quote, style) => {
					let next = String(style)
						.replace(/-webkit-text-fill-color\s*:[^;]*;?/gi, "")
						.replace(/(?:^|;)\s*color\s*:[^;]*/gi, "")
						.replace(/^;+|;+$/g, "")
						.trim();
					next = `${black} ${next}`.trim();
					return `style=${quote}${next}${quote}`;
				})}>`;
			}
			return `<${name}${attrs} style="${black}">`;
		});
	}

	insertBlockIntoNote(view: MarkdownView, block: string) {
		const editor = view.editor;
		const from = this.getInsertPosition(view);
		const text = this.isolateBlockText(editor, from, this.forceBlackHighlightText(block));
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

	stripStrongNumbersFromVerseHtml(text: string): string {
		return String(text || "")
			.replace(/<[sS]>\d+<\/[sS]>/g, "")
			.replace(/<rt class="strong-nums">[\s\S]*?<\/rt>/gi, "")
			.replace(/<span class="strong-num"[^>]*>[\s\S]*?<\/span>/gi, "")
			.replace(/<span class="strong-gap"[^>]*>([\s\S]*?)<\/span>/gi, "$1")
			.replace(/<\/?ruby[^>]*>/gi, "")
			.replace(/<\/?span class="strong-word"[^>]*>/gi, "");
	}

	isHighlightElement(el: Element): boolean {
		const tag = el.tagName.toLowerCase();
		if (tag !== "mark" && tag !== "span") {
			return false;
		}
		const style = el.getAttribute("style") || "";
		return /background/i.test(style) || /text-decoration/i.test(style);
	}

	cssStyleProperty(style: string, prop: string): string {
		const escaped = prop.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
		const match = String(style || "").match(new RegExp(`(?:^|;)\\s*${escaped}\\s*:\\s*([^;]+)`, "i"));
		return match ? match[1].trim().toLowerCase() : "";
	}

	highlightStyleKey(el: Element): string {
		const style = el.getAttribute("style") || "";
		const fill =
			this.cssStyleProperty(style, "background-color") ||
			this.cssStyleProperty(style, "background") ||
			this.cssStyleProperty(style, "background-image");
		const decoLine = this.cssStyleProperty(style, "text-decoration-line");
		const decoStyle = this.cssStyleProperty(style, "text-decoration-style");
		const decoColor = this.cssStyleProperty(style, "text-decoration-color");
		return [el.tagName.toLowerCase(), fill, decoLine, decoStyle, decoColor].join("|");
	}

	stripEmptyHighlightTags(html: string): string {
		let text = String(html || "").replace(/\s*\n\s*/g, " ");
		let prev = "";
		while (prev !== text) {
			prev = text;
			text = text.replace(/<mark\b[^>]*>\s*<\/mark>/gi, "");
			text = text.replace(/<span\b[^>]*>\s*<\/span>/gi, "");
		}
		return text.trim();
	}

	normalizeHighlightTree(root: Element): void {
		const unwrapNested = (): boolean => {
			let changed = false;
			for (const el of Array.from(root.querySelectorAll("mark, span"))) {
				const parent = el.parentElement;
				if (!parent || !this.isHighlightElement(el) || !this.isHighlightElement(parent)) {
					continue;
				}
				if (this.highlightStyleKey(parent) === this.highlightStyleKey(el)) {
					while (el.firstChild) {
						parent.insertBefore(el.firstChild, el);
					}
					el.remove();
					changed = true;
				}
			}
			return changed;
		};

		const stripEmpty = (): boolean => {
			let changed = false;
			for (const el of Array.from(root.querySelectorAll("mark, span"))) {
				if (!this.isHighlightElement(el)) {
					continue;
				}
				if (!(el.textContent || "").length) {
					el.remove();
					changed = true;
				}
			}
			return changed;
		};

		const mergeAdjacent = (parent: Element): boolean => {
			let changed = false;
			for (const child of Array.from(parent.children)) {
				if (mergeAdjacent(child)) {
					changed = true;
				}
			}
			let node = parent.firstChild;
			while (node) {
				if (node.nodeType !== 1 || !this.isHighlightElement(node as Element)) {
					node = node.nextSibling;
					continue;
				}
				let other = node.nextSibling;
				let space: ChildNode | null = null;
				if (other && other.nodeType === 3 && /^\s+$/.test(other.textContent || "")) {
					space = other;
					other = other.nextSibling;
				}
				if (
					other &&
					other.nodeType === 1 &&
					this.isHighlightElement(other as Element) &&
					this.highlightStyleKey(node as Element) === this.highlightStyleKey(other as Element)
				) {
					if (space) {
						node.appendChild(space);
					}
					while (other.firstChild) {
						node.appendChild(other.firstChild);
					}
					other.parentNode?.removeChild(other);
					changed = true;
					continue;
				}
				node = node.nextSibling;
			}
			return changed;
		};

		let guard = 0;
		while (guard < 20) {
			guard += 1;
			const changed = unwrapNested() || stripEmpty() || mergeAdjacent(root);
			if (!changed) {
				break;
			}
		}
	}

	cleanVerseHighlightHtml(html: string): string {
		const text = this.stripEmptyHighlightTags(html);
		if (!text || typeof DOMParser === "undefined") {
			return text;
		}
		try {
			const doc = new DOMParser().parseFromString(`<div>${text}</div>`, "text/html");
			const root = doc.body.firstElementChild;
			if (!root) {
				return text;
			}
			this.normalizeHighlightTree(root);
			return this.stripEmptyHighlightTags(root.innerHTML);
		} catch {
			return text;
		}
	}

	isInterlinearTranslation(code?: string, fullName?: string): boolean {
		const abbr = String(code || "").toUpperCase();
		if (abbr === "INTES") {
			return true;
		}
		const name = String(fullName || "").toLowerCase();
		return name.includes("interlineal") || name.includes("interlinear");
	}

	styleInterlinearVerseHtml(html: string): string {
		const text = String(html || "");
		if (!text || text.includes("interlinear-src")) {
			return text;
		}
		let out = "";
		let gloss = 0;
		let i = 0;
		while (i < text.length) {
			if (text[i] === "<") {
				const end = text.indexOf(">", i);
				if (end < 0) {
					out += text.slice(i);
					break;
				}
				const tag = text.slice(i, end + 1);
				const lower = tag.toLowerCase();
				if (lower.startsWith("<i") && !lower.startsWith("</")) {
					gloss += 1;
				} else if (lower.startsWith("</i")) {
					gloss = Math.max(0, gloss - 1);
				}
				out += tag;
				i = end + 1;
			} else {
				const nextTag = text.indexOf("<", i);
				const chunk = nextTag === -1 ? text.slice(i) : text.slice(i, nextTag);
				if (gloss > 0) {
					out += chunk;
				} else {
					out += chunk.replace(/[^\s<]+/g, (word) => `<span class="interlinear-src" style="opacity:.4">${word}</span>`);
				}
				i += chunk.length;
			}
		}
		return out;
	}

	getViewType() {
		return "bible-viewer";
	}

	getDisplayText() {
		return "Bible Viewer";
	}

	getIcon() {
		try {
			return this.plugin.ribbonIconId();
		} catch {
			return "book-open";
		}
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
				this.iframe.src = this.pendingNavigation || (this.plugin.settings.bibleAppUrl + cacheBuster);
				this.pendingNavigation = null;
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
		this.registerDomEvent(window, "message", this.messageHandler);
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
					this.iframe.src = this.pendingNavigation || (this.plugin.settings.bibleAppUrl + cacheBuster);
					this.pendingNavigation = null;
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

	currentTranslation(): string {
		try {
			if (this.iframe?.src) {
				const parts = new URL(this.iframe.src).pathname.split("/").filter(Boolean);
				if (parts[0] && /^[A-Za-z0-9]+$/.test(parts[0])) {
					return parts[0];
				}
			}
		} catch {
			// Ignore a bad iframe URL.
		}
		return this.plugin.settings.lastTranslation || "YLT";
	}

	rememberTranslation(code?: string) {
		const translation = String(code || "").trim();
		if (!translation) {
			return;
		}
		this.plugin.settings.lastTranslation = translation;
		void this.plugin.saveSettings();
	}

	verseAppUrl(hit: VerseHit): string {
		const base = this.plugin.settings.bibleAppUrl.replace(/\/$/, "");
		const translation = hit.translation || this.currentTranslation();
		return `${base}/${translation}/${hit.bookId}/${hit.chapter}/${hit.verse}`;
	}

	navigateToVerse(hit: VerseHit) {
		if (hit.translation) {
			this.rememberTranslation(hit.translation);
		}
		const url = this.verseAppUrl(hit);
		this.pendingNavigation = url;
		if (this.iframe) {
			this.iframe.src = url;
			this.pendingNavigation = null;
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
		interlinear?: boolean;
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
		
		const translationCode = data?.translation || this.currentTranslation();
		this.rememberTranslation(translationCode);
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
		const interlinear = Boolean(data.interlinear) || this.isInterlinearTranslation(translationCode, data.translationFullName);
		const verseTexts = verses.map((v) => {
			let text = this.cleanVerseHighlightHtml(this.stripStrongNumbersFromVerseHtml(v.text));
			if (interlinear) {
				text = this.styleInterlinearVerseHtml(text);
			}
			text = this.cleanVerseHighlightHtml(text);
			return `> ${v.verse}. ${text}`;
		}).join("\n");
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

		const translationCode = data?.translation || this.currentTranslation();
		this.rememberTranslation(translationCode);
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

		const translationCode = data?.translation || this.currentTranslation();
		this.rememberTranslation(translationCode);
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

		new Setting(containerEl)
			.setName("Detect verse references")
			.setDesc("Turn written references like Genesis 3:5 or Genesis 1:14-15 into links that open the first verse of the range in Bible Viewer. On by default.")
			.addToggle((toggle) =>
				toggle
					.setValue(this.plugin.settings.detectVerseReferences)
					.onChange(async (value) => {
						this.plugin.settings.detectVerseReferences = value;
						await this.plugin.saveSettings();
					})
			);

		new Setting(containerEl)
			.setName("Open Bible links in Bible Viewer")
			.setDesc("Clicks on Bible links, including ranges like Genesis 1:14-15, open the first verse of the range in Bible Viewer. The note is not changed.")
			.addToggle((toggle) =>
				toggle
					.setValue(this.plugin.settings.openBibleLinksInViewer)
					.onChange(async (value) => {
						this.plugin.settings.openBibleLinksInViewer = value;
						await this.plugin.saveSettings();
					})
			);
	}
}

function createVerseRefExtension(plugin: BibleViewerPlugin) {
	return ViewPlugin.fromClass(
		class {
			decorations: DecorationSet;

			constructor(view: EditorView) {
				this.decorations = this.build(view);
			}

			update(update: ViewUpdate) {
				if (update.docChanged || update.viewportChanged) {
					this.decorations = this.build(update.view);
				}
			}

			build(view: EditorView) {
				const builder = new RangeSetBuilder<Decoration>();
				if (!plugin.settings.detectVerseReferences) {
					return builder.finish();
				}
				for (const range of view.visibleRanges) {
					const text = view.state.doc.sliceString(range.from, range.to);
					for (const hit of findVerseRefs(text)) {
						builder.add(
							range.from + hit.from,
							range.from + hit.to,
							Decoration.mark({
								class: "bible-verse-ref",
								attributes: {
									"data-book-id": String(hit.bookId),
									"data-chapter": String(hit.chapter),
									"data-verse": String(hit.verse),
									"data-end-verse": hit.endVerse ? String(hit.endVerse) : "",
								},
							})
						);
					}
				}
				return builder.finish();
			}
		},
		{
			decorations: (value) => value.decorations,
			eventHandlers: {
				mousedown(event) {
					if (!plugin.settings.detectVerseReferences) {
						return false;
					}
					const target = event.target as HTMLElement | null;
					const el = target?.closest?.(".bible-verse-ref");
					const hit = verseHitFromEl(el);
					if (!hit) {
						return false;
					}
					event.preventDefault();
					void plugin.openVerseReference(hit);
					return true;
				},
			},
		}
	);
}

