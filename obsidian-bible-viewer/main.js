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
var import_state = require("@codemirror/state");
var import_view = require("@codemirror/view");

// verse-refs.ts
var BOOKS = [
  { id: 1, names: ["genesis", "g\xE9nesis", "gen", "gn"] },
  { id: 2, names: ["exodus", "\xE9xodo", "exodo", "exod", "exo", "ex"] },
  { id: 3, names: ["leviticus", "lev\xEDtico", "levitico", "lev", "lv"] },
  { id: 4, names: ["numbers", "n\xFAmeros", "numeros", "num", "n\xFAm", "nu"] },
  { id: 5, names: ["deuteronomy", "deuteronomio", "deut", "deu", "dt"] },
  { id: 6, names: ["joshua", "josu\xE9", "josue", "josh", "jos"] },
  { id: 7, names: ["judges", "jueces", "judg", "jdg", "jue"] },
  { id: 8, names: ["ruth", "rut", "rth"] },
  { id: 9, names: ["1 samuel", "1sam", "1 sam", "1 sa", "1sa", "1\xBA samuel", "1o samuel"] },
  { id: 10, names: ["2 samuel", "2sam", "2 sam", "2 sa", "2sa", "2\xBA samuel", "2o samuel"] },
  { id: 11, names: ["1 kings", "1 reyes", "1 kgs", "1 ki", "1ki", "1re", "1 re", "1\xBA reyes"] },
  { id: 12, names: ["2 kings", "2 reyes", "2 kgs", "2 ki", "2ki", "2re", "2 re", "2\xBA reyes"] },
  { id: 13, names: ["1 chronicles", "1 cr\xF3nicas", "1 cronicas", "1 chron", "1 chr", "1 cr", "1ch", "1\xBA cr\xF3nicas"] },
  { id: 14, names: ["2 chronicles", "2 cr\xF3nicas", "2 cronicas", "2 chron", "2 chr", "2 cr", "2ch", "2\xBA cr\xF3nicas"] },
  { id: 15, names: ["ezra", "esdras", "ezr", "esd"] },
  { id: 16, names: ["nehemiah", "nehem\xEDas", "nehemias", "neh"] },
  { id: 17, names: ["esther", "ester", "esth", "est"] },
  { id: 18, names: ["job"] },
  { id: 19, names: ["psalms", "psalm", "salmos", "salmo", "psa", "ps", "sal"] },
  { id: 20, names: ["proverbs", "proverbios", "prov", "pro", "prv"] },
  { id: 21, names: ["ecclesiastes", "eclesiast\xE9s", "eclesiastes", "eccl", "ecc", "ecl"] },
  { id: 22, names: ["song of solomon", "song of songs", "cantar de los cantares", "cantares", "song", "cant", "cnt"] },
  { id: 23, names: ["isaiah", "isa\xEDas", "isaias", "isa"] },
  { id: 24, names: ["jeremiah", "jerem\xEDas", "jeremias", "jer"] },
  { id: 25, names: ["lamentations", "lamentaciones", "lam"] },
  { id: 26, names: ["ezekiel", "ezequiel", "ezek", "ezeq", "eze"] },
  { id: 27, names: ["daniel", "dan", "dn"] },
  { id: 28, names: ["hosea", "oseas", "hos", "os"] },
  { id: 29, names: ["joel", "jl"] },
  { id: 30, names: ["amos", "am\xF3s"] },
  { id: 31, names: ["obadiah", "abd\xEDas", "abdias", "obad", "oba", "abd"] },
  { id: 32, names: ["jonah", "jon\xE1s", "jonas", "jon"] },
  { id: 33, names: ["micah", "miqueas", "mic", "miq"] },
  { id: 34, names: ["nahum", "nah"] },
  { id: 35, names: ["habakkuk", "habacuc", "hab"] },
  { id: 36, names: ["zephaniah", "sofon\xEDas", "sofonias", "zeph", "zep", "sof"] },
  { id: 37, names: ["haggai", "hageo", "hag"] },
  { id: 38, names: ["zechariah", "zacar\xEDas", "zacarias", "zech", "zec", "zac"] },
  { id: 39, names: ["malachi", "malaqu\xEDas", "malaquias", "mal"] },
  { id: 40, names: ["matthew", "mateo", "matt", "mat", "mt"] },
  { id: 41, names: ["mark", "marcos", "mrk", "mar", "mk", "mc"] },
  { id: 42, names: ["luke", "lucas", "luk", "lk", "lc"] },
  { id: 62, names: ["1 john", "1 juan", "1 jn", "1jn", "1\xBA juan", "1o juan"] },
  { id: 63, names: ["2 john", "2 juan", "2 jn", "2jn", "2\xBA juan", "2o juan"] },
  { id: 64, names: ["3 john", "3 juan", "3 jn", "3jn", "3\xBA juan", "3o juan"] },
  { id: 43, names: ["john", "juan", "jhn", "jn"] },
  { id: 44, names: ["acts", "hechos", "act", "hch", "hc"] },
  { id: 45, names: ["romans", "romanos", "rom", "ro"] },
  { id: 46, names: ["1 corinthians", "1 corintios", "1 cor", "1cor", "1 co", "1\xBA corintios"] },
  { id: 47, names: ["2 corinthians", "2 corintios", "2 cor", "2cor", "2 co", "2\xBA corintios"] },
  { id: 48, names: ["galatians", "g\xE1latas", "galatas", "gal"] },
  { id: 49, names: ["ephesians", "efesios", "eph", "ef"] },
  { id: 50, names: ["philippians", "filipenses", "phil", "php", "fil"] },
  { id: 51, names: ["colossians", "colosenses", "col"] },
  { id: 52, names: ["1 thessalonians", "1 tesalonicenses", "1 thess", "1 tes", "1th", "1tes"] },
  { id: 53, names: ["2 thessalonians", "2 tesalonicenses", "2 thess", "2 tes", "2th", "2tes"] },
  { id: 54, names: ["1 timothy", "1 timoteo", "1 tim", "1tim", "1 ti"] },
  { id: 55, names: ["2 timothy", "2 timoteo", "2 tim", "2tim", "2 ti"] },
  { id: 56, names: ["titus", "tito", "tit", "tt"] },
  { id: 57, names: ["philemon", "filem\xF3n", "filemon", "phlm", "phm", "flm"] },
  { id: 58, names: ["hebrews", "hebreos", "heb"] },
  { id: 59, names: ["james", "santiago", "jas", "stg", "st"] },
  { id: 60, names: ["1 peter", "1 pedro", "1 pet", "1 pe", "1pe", "1ped"] },
  { id: 61, names: ["2 peter", "2 pedro", "2 pet", "2 pe", "2pe", "2ped"] },
  { id: 65, names: ["jude", "judas"] },
  { id: 66, names: ["revelation", "apocalipsis", "rev", "apoc", "ap"] }
];
function fold(value) {
  return String(value || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[ºª]/g, "o").replace(/\s+/g, " ").trim();
}
function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
var ALIAS_TO_ID = /* @__PURE__ */ new Map();
var ALIASES = [];
for (const book of BOOKS) {
  for (const name of book.names) {
    const key = fold(name);
    if (!key || ALIAS_TO_ID.has(key)) {
      continue;
    }
    ALIAS_TO_ID.set(key, book.id);
    ALIASES.push(key);
  }
}
ALIASES.sort((a, b) => b.length - a.length);
var BOOK_RE = ALIASES.map((alias) => escapeRegExp(alias).replace(/ /g, "\\s+")).join("|");
var VERSE_RE = new RegExp(
  `(^|[^A-Za-z0-9\xC1\xC9\xCD\xD3\xDA\xE1\xE9\xED\xF3\xFA\xD1\xF1])(${BOOK_RE})\\s+(\\d{1,3})\\s*:\\s*(\\d{1,3})(?:\\s*[-\u2013\u2014]\\s*(\\d{1,3}))?`,
  "giu"
);
var SKIP_PARENTS = "a, code, pre, .bible-verse-ref, .cm-inline-code, .internal-link, .external-link";
function findVerseRefs(text) {
  const hits = [];
  if (!text || text.indexOf(":") < 0) {
    return hits;
  }
  VERSE_RE.lastIndex = 0;
  let match;
  while ((match = VERSE_RE.exec(text)) !== null) {
    const boundary = match[1] || "";
    const bookRaw = match[2];
    const bookId = ALIAS_TO_ID.get(fold(bookRaw));
    const chapter = Number(match[3]);
    const verse = Number(match[4]);
    const endVerse = match[5] ? Number(match[5]) : void 0;
    if (!bookId || !chapter || !verse) {
      continue;
    }
    if (endVerse && endVerse < verse) {
      continue;
    }
    const from = match.index + boundary.length;
    const to = match.index + match[0].length;
    hits.push({
      bookId,
      chapter,
      verse,
      endVerse: endVerse && endVerse !== verse ? endVerse : void 0,
      from,
      to,
      text: text.slice(from, to)
    });
  }
  return hits;
}
function verseHitFromEl(el) {
  if (!el) {
    return null;
  }
  const bookId = Number(el.getAttribute("data-book-id"));
  const chapter = Number(el.getAttribute("data-chapter"));
  const verse = Number(el.getAttribute("data-verse"));
  const endRaw = el.getAttribute("data-end-verse");
  const endVerse = endRaw ? Number(endRaw) : void 0;
  if (!bookId || !chapter || !verse) {
    return null;
  }
  return {
    bookId,
    chapter,
    verse,
    endVerse: endVerse || void 0,
    from: 0,
    to: 0,
    text: el.textContent || ""
  };
}
function applyHitAttributes(el, hit) {
  el.classList.add("bible-verse-ref");
  el.setAttribute("data-book-id", String(hit.bookId));
  el.setAttribute("data-chapter", String(hit.chapter));
  el.setAttribute("data-verse", String(hit.verse));
  if (hit.endVerse) {
    el.setAttribute("data-end-verse", String(hit.endVerse));
  }
  el.setAttribute("title", `Open ${hit.text} in Bible Viewer`);
}
function decorateVerseRefs(root) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
    acceptNode(node) {
      const parent = node.parentElement;
      if (!parent) {
        return NodeFilter.FILTER_REJECT;
      }
      if (parent.closest(SKIP_PARENTS)) {
        return NodeFilter.FILTER_REJECT;
      }
      const value = node.nodeValue || "";
      if (value.indexOf(":") < 0) {
        return NodeFilter.FILTER_REJECT;
      }
      return NodeFilter.FILTER_ACCEPT;
    }
  });
  const nodes = [];
  let current = walker.nextNode();
  while (current) {
    nodes.push(current);
    current = walker.nextNode();
  }
  for (const node of nodes) {
    const value = node.nodeValue || "";
    const hits = findVerseRefs(value);
    if (!hits.length || !node.parentNode) {
      continue;
    }
    const frag = document.createDocumentFragment();
    let cursor = 0;
    for (const hit of hits) {
      if (hit.from > cursor) {
        frag.appendChild(document.createTextNode(value.slice(cursor, hit.from)));
      }
      const link = document.createElement("span");
      applyHitAttributes(link, hit);
      link.textContent = value.slice(hit.from, hit.to);
      frag.appendChild(link);
      cursor = hit.to;
    }
    if (cursor < value.length) {
      frag.appendChild(document.createTextNode(value.slice(cursor)));
    }
    node.parentNode.replaceChild(frag, node);
  }
}

// main.ts
var DEFAULT_SETTINGS = {
  bibleAppUrl: "https://bolls.familybravo.com",
  detectVerseReferences: true,
  lastTranslation: ""
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
      (event) => {
        var _a;
        if (!this.settings.detectVerseReferences) {
          return;
        }
        const target = event.target;
        const el = (_a = target == null ? void 0 : target.closest) == null ? void 0 : _a.call(target, ".bible-verse-ref");
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
    this.app.workspace.onLayoutReady(() => {
      this.activateView();
    });
  }
  async openVerseReference(hit) {
    await this.activateView();
    const view = this.bibleView;
    if (!view) {
      new import_obsidian.Notice("Bible Viewer is not open.");
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
    this.pendingNavigation = null;
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
        this.iframe.src = this.pendingNavigation || this.plugin.settings.bibleAppUrl + cacheBuster;
        this.pendingNavigation = null;
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
          this.iframe.src = this.pendingNavigation || this.plugin.settings.bibleAppUrl + cacheBuster;
          this.pendingNavigation = null;
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
  currentTranslation() {
    var _a;
    try {
      if ((_a = this.iframe) == null ? void 0 : _a.src) {
        const parts = new URL(this.iframe.src).pathname.split("/").filter(Boolean);
        if (parts[0] && /^[A-Za-z0-9]+$/.test(parts[0])) {
          return parts[0];
        }
      }
    } catch (e) {
    }
    return this.plugin.settings.lastTranslation || "YLT";
  }
  rememberTranslation(code) {
    const translation = String(code || "").trim();
    if (!translation) {
      return;
    }
    this.plugin.settings.lastTranslation = translation;
    void this.plugin.saveSettings();
  }
  verseAppUrl(hit) {
    const base = this.plugin.settings.bibleAppUrl.replace(/\/$/, "");
    const translation = this.currentTranslation();
    const versePart = hit.endVerse && hit.endVerse !== hit.verse ? `${hit.verse}-${hit.endVerse}` : `${hit.verse}`;
    return `${base}/${translation}/${hit.bookId}/${hit.chapter}/${versePart}`;
  }
  navigateToVerse(hit) {
    const url = this.verseAppUrl(hit);
    this.pendingNavigation = url;
    if (this.iframe) {
      this.iframe.src = url;
      this.pendingNavigation = null;
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
    const translationCode = (data == null ? void 0 : data.translation) || this.currentTranslation();
    this.rememberTranslation(translationCode);
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
    const translationCode = (data == null ? void 0 : data.translation) || this.currentTranslation();
    this.rememberTranslation(translationCode);
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
    const definition = String(data.definition || "").trim();
    if (!definition) {
      new import_obsidian.Notice("No dictionary entry to copy.");
      return;
    }
    const activeView = this.getMarkdownViewForInsert();
    if (!activeView) {
      new import_obsidian.Notice("No active note to copy dictionary entry to.");
      return;
    }
    const translationCode = (data == null ? void 0 : data.translation) || this.currentTranslation();
    this.rememberTranslation(translationCode);
    const bookId = data.bookId || 1;
    const chapter = data.chapter || 1;
    const verse = data.verse || 1;
    const dictionaryCode = data.dictionary || "";
    const topic = data.topic || data.query || "";
    const titleBits = [dictionaryCode, topic].filter((bit) => bit && String(bit).trim().length > 0);
    const title = titleBits.join(" \xB7 ") || data.dictionaryName || "Dictionary";
    const url = `${this.plugin.settings.bibleAppUrl}/${translationCode}/${bookId}/${chapter}/${verse}`;
    const body = definition.split(/\n+/).filter((line) => line.trim().length > 0).map((line) => `> ${line.trim()}`).join("\n");
    const calloutHeader = `> [!dictionary] [${title}](${url})`;
    const heading = String(data.heading || "").trim();
    const formattedText = heading ? `${calloutHeader}
> ${heading}
${body}` : `${calloutHeader}
${body}`;
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
    new import_obsidian.Setting(containerEl).setName("Detect verse references").setDesc("Turn written references like Genesis 3:5 into links that open that verse in Bible Viewer. On by default.").addToggle(
      (toggle) => toggle.setValue(this.plugin.settings.detectVerseReferences).onChange(async (value) => {
        this.plugin.settings.detectVerseReferences = value;
        await this.plugin.saveSettings();
      })
    );
  }
};
function createVerseRefExtension(plugin) {
  return import_view.ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.decorations = this.build(view);
      }
      update(update) {
        if (update.docChanged || update.viewportChanged) {
          this.decorations = this.build(update.view);
        }
      }
      build(view) {
        const builder = new import_state.RangeSetBuilder();
        if (!plugin.settings.detectVerseReferences) {
          return builder.finish();
        }
        for (const range of view.visibleRanges) {
          const text = view.state.doc.sliceString(range.from, range.to);
          for (const hit of findVerseRefs(text)) {
            builder.add(
              range.from + hit.from,
              range.from + hit.to,
              import_view.Decoration.mark({
                class: "bible-verse-ref",
                attributes: {
                  "data-book-id": String(hit.bookId),
                  "data-chapter": String(hit.chapter),
                  "data-verse": String(hit.verse),
                  "data-end-verse": hit.endVerse ? String(hit.endVerse) : ""
                }
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
          var _a;
          if (!plugin.settings.detectVerseReferences) {
            return false;
          }
          const target = event.target;
          const el = (_a = target == null ? void 0 : target.closest) == null ? void 0 : _a.call(target, ".bible-verse-ref");
          const hit = verseHitFromEl(el);
          if (!hit) {
            return false;
          }
          event.preventDefault();
          void plugin.openVerseReference(hit);
          return true;
        }
      }
    }
  );
}
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {});
