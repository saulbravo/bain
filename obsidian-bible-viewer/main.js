var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// main.ts
var main_exports = {};
__export(main_exports, {
  default: () => BibleViewerPlugin
});
module.exports = __toCommonJS(main_exports);
var import_obsidian = require("obsidian");
var DEFAULT_SETTINGS = {
  bibleAppUrl: "https://bolls.familybravo.com"
};
var BibleViewerPlugin = class extends import_obsidian.Plugin {
  async onload() {
    await this.loadSettings();
    this.registerView(
      "bible-viewer",
      (leaf) => this.bibleView = new BibleView(leaf, this)
    );
    this.addCommand({
      id: "open-bible-viewer",
      name: "Open Bible Viewer",
      callback: () => {
        this.activateView();
      }
    });
    this.addRibbonIcon("book-open", "Open Bible Viewer", () => {
      this.activateView();
    });
    this.addSettingTab(new BibleViewerSettingTab(this.app, this));
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
    if (this.settings.bibleAppUrl === "http://localhost:8080" || this.settings.bibleAppUrl === "http://127.0.0.1:8080") {
      this.settings.bibleAppUrl = DEFAULT_SETTINGS.bibleAppUrl;
      await this.saveSettings();
    }
  }
  async saveSettings() {
    await this.saveData(this.settings);
  }
  async activateView() {
    const { workspace } = this.app;
    let leaf = null;
    const leaves = workspace.getLeavesOfType("bible-viewer");
    if (leaves.length > 0) {
      leaf = leaves[0];
    } else {
      leaf = workspace.getRightLeaf(false);
      await leaf.setViewState({
        type: "bible-viewer",
        active: true
      });
    }
    workspace.revealLeaf(leaf);
  }
};
var BibleView = class extends import_obsidian.ItemView {
  constructor(leaf, plugin) {
    super(leaf);
    this.lastMarkdownLeaf = null;
    this.lastEditorCursor = null;
    this.plugin = plugin;
    this.messageHandler = this.handleMessage.bind(this);
  }
  snapshotMarkdownCursor(view) {
    var _a, _b;
    if (!view) {
      return;
    }
    this.lastMarkdownLeaf = view.leaf;
    try {
      const cursor = view.editor.getCursor();
      this.lastEditorCursor = {
        path: (_b = (_a = view.file) == null ? void 0 : _a.path) != null ? _b : "",
        line: cursor.line,
        ch: cursor.ch
      };
    } catch (e) {
    }
  }
  rememberMarkdownLeaf(leaf) {
    if ((leaf == null ? void 0 : leaf.view) instanceof import_obsidian.MarkdownView) {
      this.snapshotMarkdownCursor(leaf.view);
    }
  }
  getMarkdownViewForInsert() {
    var _a;
    const activeView = this.app.workspace.getActiveViewOfType(import_obsidian.MarkdownView);
    if (activeView) {
      this.lastMarkdownLeaf = activeView.leaf;
      return activeView;
    }
    if (((_a = this.lastMarkdownLeaf) == null ? void 0 : _a.view) instanceof import_obsidian.MarkdownView) {
      return this.lastMarkdownLeaf.view;
    }
    const markdownLeaves = this.app.workspace.getLeavesOfType("markdown");
    for (const leaf of markdownLeaves) {
      if (leaf.view instanceof import_obsidian.MarkdownView) {
        this.lastMarkdownLeaf = leaf;
        return leaf.view;
      }
    }
    return null;
  }
  clampEditorPosition(editor, pos) {
    var _a, _b;
    const lastLine = Math.max(0, editor.lastLine());
    const line = Math.max(0, Math.min(pos.line, lastLine));
    const lineLength = (_b = (_a = editor.getLine(line)) == null ? void 0 : _a.length) != null ? _b : 0;
    const ch = Math.max(0, Math.min(pos.ch, lineLength));
    return { line, ch };
  }
  getInsertPosition(view) {
    var _a, _b;
    const editor = view.editor;
    const path = (_b = (_a = view.file) == null ? void 0 : _a.path) != null ? _b : "";
    const activeMarkdown = this.app.workspace.getActiveViewOfType(import_obsidian.MarkdownView);
    if (activeMarkdown === view) {
      return editor.getCursor();
    }
    if (this.lastEditorCursor && this.lastEditorCursor.path === path) {
      return this.clampEditorPosition(editor, this.lastEditorCursor);
    }
    return { line: 0, ch: 0 };
  }
  positionAfterInsert(from, text) {
    const lines = text.split("\n");
    return {
      line: from.line + lines.length - 1,
      ch: lines[lines.length - 1].length
    };
  }
  isolateBlockText(editor, pos, block) {
    var _a, _b;
    let text = block.replace(/\s+$/, "") + "\n\n";
    const line = (_a = editor.getLine(pos.line)) != null ? _a : "";
    const atDocStart = pos.line === 0 && pos.ch === 0;
    const atLineStart = pos.ch === 0;
    if (!atLineStart) {
      text = (line.startsWith(">") ? "\n\n" : "\n") + text;
    } else if (!atDocStart) {
      const prevLine = (_b = editor.getLine(pos.line - 1)) != null ? _b : "";
      if (prevLine.startsWith(">")) {
        text = "\n" + text;
      }
    }
    return text;
  }
  insertBlockIntoNote(view, block) {
    var _a, _b;
    const editor = view.editor;
    const from = this.getInsertPosition(view);
    const text = this.isolateBlockText(editor, from, block);
    editor.replaceRange(text, from);
    const end = this.positionAfterInsert(from, text);
    editor.setCursor(end);
    this.lastEditorCursor = {
      path: (_b = (_a = view.file) == null ? void 0 : _a.path) != null ? _b : "",
      line: end.line,
      ch: end.ch
    };
    this.lastMarkdownLeaf = view.leaf;
  }
  stripStrongNumbersFromVerseHtml(text) {
    return String(text || "").replace(/<[sS]>\d+<\/[sS]>/g, "").replace(/<rt class="strong-nums">[\s\S]*?<\/rt>/gi, "").replace(/<span class="strong-num"[^>]*>[\s\S]*?<\/span>/gi, "").replace(/<span class="strong-gap"[^>]*>([\s\S]*?)<\/span>/gi, "$1").replace(/<\/?ruby[^>]*>/gi, "").replace(/<\/?span class="strong-word"[^>]*>/gi, "");
  }
  isInterlinearTranslation(code, fullName) {
    const abbr = String(code || "").toUpperCase();
    if (abbr === "INTES") {
      return true;
    }
    const name = String(fullName || "").toLowerCase();
    return name.includes("interlineal") || name.includes("interlinear");
  }
  styleInterlinearVerseHtml(html) {
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
    return "book-open";
  }
  async onOpen() {
    this.rememberMarkdownLeaf(this.app.workspace.activeLeaf);
    const openMarkdown = this.app.workspace.getActiveViewOfType(import_obsidian.MarkdownView);
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
        if (info instanceof import_obsidian.MarkdownView) {
          this.snapshotMarkdownCursor(info);
        }
      })
    );
    this.registerDomEvent(document, "click", () => {
      const view = this.app.workspace.getActiveViewOfType(import_obsidian.MarkdownView);
      if (view) {
        this.snapshotMarkdownCursor(view);
      }
    });
    const container = this.containerEl.children[1];
    container.empty();
    container.addClass("bible-viewer-container");
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(7);
    const cacheBuster = `?v=${timestamp}&_nocache=1&_refresh=${random}&_t=${timestamp}&_r=${random}&sw=bypass&_cb=${timestamp}${random}`;
    this.iframe = container.createEl("iframe", {
      cls: "bible-viewer-iframe",
      attr: {
        sandbox: "allow-same-origin allow-scripts allow-forms allow-popups"
      }
    });
    setTimeout(() => {
      if (this.iframe) {
        this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
        console.log("Bible Viewer: Iframe src set with cache-buster:", cacheBuster);
        let cacheCleared = false;
        this.iframe.onload = () => {
          if (cacheCleared) {
            return;
          }
          cacheCleared = true;
          setTimeout(() => {
            var _a;
            try {
              const iframeWindow = (_a = this.iframe) == null ? void 0 : _a.contentWindow;
              if (iframeWindow) {
                iframeWindow.postMessage({ type: "clear-cache", force: true, timestamp: Date.now() }, "*");
                console.log("Bible Viewer: Sent clear-cache message to iframe");
                iframeWindow.postMessage({ type: "unregister-sw", force: true, timestamp: Date.now() }, "*");
              }
            } catch (e) {
              console.log("Bible Viewer: Could not access iframe window (expected if cross-origin)");
            }
          }, 500);
        };
      }
    }, 10);
    this.registerDomEvent(window, "message", this.messageHandler);
    console.log("Bible Viewer: Message listener added, iframe loaded with cache-buster:", cacheBuster);
  }
  async onload() {
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
    if (this.iframe) {
      const timestamp = Date.now();
      const random = Math.random().toString(36).substring(7);
      const cacheBuster = `?v=${timestamp}&_nocache=1&_refresh=${random}&_t=${timestamp}&_r=${random}&sw=bypass&_force=1&_cb=${timestamp}${random}`;
      const oldIframe = this.iframe;
      const container = oldIframe.parentElement;
      oldIframe.remove();
      this.iframe = container.createEl("iframe", {
        cls: "bible-viewer-iframe",
        attr: {
          sandbox: "allow-same-origin allow-scripts allow-forms allow-popups"
        }
      });
      setTimeout(() => {
        if (this.iframe) {
          this.iframe.src = this.plugin.settings.bibleAppUrl + cacheBuster;
          console.log("Bible Viewer: Iframe recreated with cache-buster:", cacheBuster);
          let cacheCleared = false;
          this.iframe.onload = () => {
            if (cacheCleared) {
              return;
            }
            cacheCleared = true;
            setTimeout(() => {
              var _a;
              try {
                const iframeWindow = (_a = this.iframe) == null ? void 0 : _a.contentWindow;
                if (iframeWindow) {
                  iframeWindow.postMessage({ type: "clear-cache", force: true, timestamp: Date.now() }, "*");
                  console.log("Bible Viewer: Sent clear-cache message to iframe after refresh");
                  iframeWindow.postMessage({ type: "unregister-sw", force: true, timestamp: Date.now() }, "*");
                }
              } catch (e) {
                console.log("Bible Viewer: Could not access iframe window (expected if cross-origin)");
              }
            }, 500);
          };
        }
      }, 10);
    }
  }
  isAllowedMessageOrigin(origin) {
    if (origin === "null" || origin === window.location.origin) {
      return true;
    }
    if (origin.includes("localhost") || origin.includes("127.0.0.1")) {
      return true;
    }
    try {
      return new URL(origin).origin === new URL(this.plugin.settings.bibleAppUrl).origin;
    } catch (e) {
      return false;
    }
  }
  handleMessage(event) {
    var _a;
    console.log("Bible Viewer: Received message", {
      origin: event.origin,
      data: event.data,
      dataType: typeof event.data,
      dataKeys: event.data ? Object.keys(event.data) : [],
      source: event.source
    });
    const fromIframe = event.source === ((_a = this.iframe) == null ? void 0 : _a.contentWindow);
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
  postToIframe(payload) {
    var _a, _b;
    (_b = (_a = this.iframe) == null ? void 0 : _a.contentWindow) == null ? void 0 : _b.postMessage(payload, "*");
  }
  newBlockId() {
    const bytes = new Uint8Array(6);
    crypto.getRandomValues(bytes);
    return `bolls-${Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("")}`;
  }
  sanitizeBlockId(id) {
    const cleaned = String(id || "").replace(/[^A-Za-z0-9_-]/g, "").slice(0, 64);
    return cleaned || this.newBlockId();
  }
  async openNoteAtBlock(path, blockId) {
    if (!path) {
      new import_obsidian.Notice("No note path to open.");
      this.reportLinkStatus(blockId, true);
      return;
    }
    const file = this.app.vault.getAbstractFileByPath(path);
    if (!(file instanceof import_obsidian.TFile)) {
      new import_obsidian.Notice(`Could not open note: ${path}`);
      this.reportLinkStatus(blockId, true);
      return;
    }
    let broken = false;
    if (blockId) {
      try {
        const content = await this.app.vault.cachedRead(file);
        broken = !content.includes(`^${blockId}`);
      } catch (e) {
        broken = true;
      }
    }
    this.reportLinkStatus(blockId, broken);
    if (broken) {
      new import_obsidian.Notice("That Bible passage is no longer in the note.");
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
      new import_obsidian.Notice(`Could not open note: ${path}`);
      this.reportLinkStatus(blockId, true);
    }
  }
  reportLinkStatus(blockId, broken) {
    if (!blockId) {
      return;
    }
    this.postToIframe({
      type: "bible-note-link-status",
      blockId,
      broken
    });
  }
  copyVersesToNote(data) {
    const verses = data.verses;
    console.log("Bible Viewer: copyVersesToNote called with", data);
    console.log("Bible Viewer: Data keys:", Object.keys(data));
    console.log("Bible Viewer: Translation field:", data.translation);
    if (!verses || verses.length === 0) {
      new import_obsidian.Notice("No verses selected to copy.");
      return;
    }
    const activeView = this.getMarkdownViewForInsert();
    if (!activeView) {
      console.log("Bible Viewer: No active markdown view");
      new import_obsidian.Notice("No active note to copy verses to.");
      return;
    }
    console.log("Bible Viewer: Active view found", activeView);
    const firstVerse = verses[0];
    const lastVerse = verses[verses.length - 1];
    let referenceText;
    if (verses.length === 1) {
      referenceText = firstVerse.reference;
    } else {
      if (firstVerse.verse === lastVerse.verse) {
        referenceText = firstVerse.reference;
      } else {
        referenceText = `${firstVerse.reference}-${lastVerse.verse}`;
      }
    }
    console.log("Bible Viewer: Full data object received:", JSON.stringify(data, null, 2));
    console.log("Bible Viewer: data.translation value:", data.translation);
    console.log("Bible Viewer: All data keys:", Object.keys(data || {}));
    const translationCode = (data == null ? void 0 : data.translation) || "BBE";
    console.log("Bible Viewer: Using translation code:", translationCode);
    const bookId = data.bookId || 1;
    const chapter = data.chapter || 1;
    let verseRange;
    if (verses.length === 1) {
      verseRange = `${firstVerse.verse}`;
    } else {
      verseRange = `${firstVerse.verse}-${lastVerse.verse}`;
    }
    const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verseRange}`;
    const calloutHeader = `> [!bible] [${referenceText} - ${translationCode}](${url})`;
    const interlinear = Boolean(data.interlinear) || this.isInterlinearTranslation(translationCode, data.translationFullName);
    const verseTexts = verses.map((v) => {
      let text = this.stripStrongNumbersFromVerseHtml(v.text);
      if (interlinear) {
        text = this.styleInterlinearVerseHtml(text);
      }
      return `> ${v.verse}. ${text}`;
    }).join("\n");
    const blockId = this.sanitizeBlockId(data.blockId || this.newBlockId());
    const formattedText = `${calloutHeader}
${verseTexts}
> ^${blockId}`;
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
        endVerse: Number(data.endVerse || lastVerse.verse)
      });
    }
    new import_obsidian.Notice(`Copied ${verses.length} verse${verses.length > 1 ? "s" : ""} to note`);
  }
  copyCommentaryToNote(data) {
    var _a, _b;
    const sections = data.sections || [];
    if (sections.length === 0) {
      new import_obsidian.Notice("No commentary to copy.");
      return;
    }
    const activeView = this.getMarkdownViewForInsert();
    if (!activeView) {
      new import_obsidian.Notice("No active note to copy commentary to.");
      return;
    }
    const translationCode = (data == null ? void 0 : data.translation) || "BBE";
    const bookId = data.bookId || 1;
    const chapter = data.chapter || 1;
    const verse = ((_a = sections[0]) == null ? void 0 : _a.verse) || 1;
    const title = data.commentaryTitle || "Comentario B\xEDblico Adventista";
    const reference = data.reference || ((_b = sections[0]) == null ? void 0 : _b.reference) || `${data.book || "Genesis"} ${chapter}:${verse}`;
    const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verse}`;
    const body = sections.map((section) => section.text.trim()).filter((text) => text.length > 0).map(
      (text) => text.split(/\n+/).filter((line) => line.trim().length > 0).map((line) => `> ${line.trim()}`).join("\n")
    ).join("\n>\n");
    const calloutHeader = `> [!note] [${title}](${url})`;
    const subtitleLine = `> ${reference}`;
    const formattedText = `${calloutHeader}
${subtitleLine}
${body}`;
    this.insertBlockIntoNote(activeView, formattedText);
    new import_obsidian.Notice(`Copied commentary to note`);
  }
  copyDictionaryToNote(data) {
    const definition = String((data == null ? void 0 : data.definition) || "").trim();
    if (!definition) {
      new import_obsidian.Notice("No dictionary entry to copy.");
      return;
    }
    const activeView = this.getMarkdownViewForInsert();
    if (!activeView) {
      new import_obsidian.Notice("No active note to copy dictionary entry to.");
      return;
    }
    const translationCode = (data == null ? void 0 : data.translation) || "BBE";
    const bookId = data.bookId || 1;
    const chapter = data.chapter || 1;
    const verse = data.verse || 1;
    const dictionaryCode = data.dictionary || "";
    const topic = data.topic || data.query || "";
    const titleBits = [dictionaryCode, topic].filter((bit) => bit && String(bit).trim().length > 0);
    const title = titleBits.join(" · ") || data.dictionaryName || "Dictionary";
    const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verse}`;
    const body = definition.split(/\n+/).filter((line) => line.trim().length > 0).map((line) => `> ${line.trim()}`).join("\n");
    const calloutHeader = `> [!dictionary] [${title}](${url})`;
    const heading = String(data.heading || "").trim();
    const formattedText = heading ? `${calloutHeader}\n> ${heading}\n${body}` : `${calloutHeader}\n${body}`;
    this.insertBlockIntoNote(activeView, formattedText);
    new import_obsidian.Notice("Copied dictionary entry to note");
  }
};
var BibleViewerSettingTab = class extends import_obsidian.PluginSettingTab {
  constructor(app, plugin) {
    super(app, plugin);
    this.plugin = plugin;
  }
  display() {
    const { containerEl } = this;
    containerEl.empty();
    containerEl.createEl("h2", { text: "Bible Viewer Settings" });
    new import_obsidian.Setting(containerEl).setName("Bible App URL").setDesc("URL of the Bible app (default: https://bolls.familybravo.com)").addText(
      (text) => text.setPlaceholder("https://bolls.familybravo.com").setValue(this.plugin.settings.bibleAppUrl).onChange(async (value) => {
        this.plugin.settings.bibleAppUrl = value;
        await this.plugin.saveSettings();
        if (this.plugin.bibleView) {
          const cacheBuster = `?v=${Date.now()}&_nocache=1&_refresh=${Math.random()}`;
          this.plugin.bibleView.refreshIframe();
        }
      })
    );
  }
};
