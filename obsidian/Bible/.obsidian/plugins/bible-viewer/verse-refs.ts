export interface VerseHit {
	bookId: number;
	chapter: number;
	verse: number;
	endVerse?: number;
	from: number;
	to: number;
	text: string;
}

interface BookEntry {
	id: number;
	names: string[];
}

// App book ids 1-66. Longer names first so "1 John" wins over "John".
const BOOKS: BookEntry[] = [
	{ id: 1, names: ["genesis", "génesis", "gen", "gn"] },
	{ id: 2, names: ["exodus", "éxodo", "exodo", "exod", "exo", "ex"] },
	{ id: 3, names: ["leviticus", "levítico", "levitico", "lev", "lv"] },
	{ id: 4, names: ["numbers", "números", "numeros", "num", "núm", "nu"] },
	{ id: 5, names: ["deuteronomy", "deuteronomio", "deut", "deu", "dt"] },
	{ id: 6, names: ["joshua", "josué", "josue", "josh", "jos"] },
	{ id: 7, names: ["judges", "jueces", "judg", "jdg", "jue"] },
	{ id: 8, names: ["ruth", "rut", "rth"] },
	{ id: 9, names: ["1 samuel", "1sam", "1 sam", "1 sa", "1sa", "1º samuel", "1o samuel"] },
	{ id: 10, names: ["2 samuel", "2sam", "2 sam", "2 sa", "2sa", "2º samuel", "2o samuel"] },
	{ id: 11, names: ["1 kings", "1 reyes", "1 kgs", "1 ki", "1ki", "1re", "1 re", "1º reyes"] },
	{ id: 12, names: ["2 kings", "2 reyes", "2 kgs", "2 ki", "2ki", "2re", "2 re", "2º reyes"] },
	{ id: 13, names: ["1 chronicles", "1 crónicas", "1 cronicas", "1 chron", "1 chr", "1 cr", "1ch", "1º crónicas"] },
	{ id: 14, names: ["2 chronicles", "2 crónicas", "2 cronicas", "2 chron", "2 chr", "2 cr", "2ch", "2º crónicas"] },
	{ id: 15, names: ["ezra", "esdras", "ezr", "esd"] },
	{ id: 16, names: ["nehemiah", "nehemías", "nehemias", "neh"] },
	{ id: 17, names: ["esther", "ester", "esth", "est"] },
	{ id: 18, names: ["job"] },
	{ id: 19, names: ["psalms", "psalm", "salmos", "salmo", "psa", "ps", "sal"] },
	{ id: 20, names: ["proverbs", "proverbios", "prov", "pro", "prv"] },
	{ id: 21, names: ["ecclesiastes", "eclesiastés", "eclesiastes", "eccl", "ecc", "ecl"] },
	{ id: 22, names: ["song of solomon", "song of songs", "cantar de los cantares", "cantares", "song", "cant", "cnt"] },
	{ id: 23, names: ["isaiah", "isaías", "isaias", "isa"] },
	{ id: 24, names: ["jeremiah", "jeremías", "jeremias", "jer"] },
	{ id: 25, names: ["lamentations", "lamentaciones", "lam"] },
	{ id: 26, names: ["ezekiel", "ezequiel", "ezek", "ezeq", "eze"] },
	{ id: 27, names: ["daniel", "dan", "dn"] },
	{ id: 28, names: ["hosea", "oseas", "hos", "os"] },
	{ id: 29, names: ["joel", "jl"] },
	{ id: 30, names: ["amos", "amós"] },
	{ id: 31, names: ["obadiah", "abdías", "abdias", "obad", "oba", "abd"] },
	{ id: 32, names: ["jonah", "jonás", "jonas", "jon"] },
	{ id: 33, names: ["micah", "miqueas", "mic", "miq"] },
	{ id: 34, names: ["nahum", "nah"] },
	{ id: 35, names: ["habakkuk", "habacuc", "hab"] },
	{ id: 36, names: ["zephaniah", "sofonías", "sofonias", "zeph", "zep", "sof"] },
	{ id: 37, names: ["haggai", "hageo", "hag"] },
	{ id: 38, names: ["zechariah", "zacarías", "zacarias", "zech", "zec", "zac"] },
	{ id: 39, names: ["malachi", "malaquías", "malaquias", "mal"] },
	{ id: 40, names: ["matthew", "mateo", "matt", "mat", "mt"] },
	{ id: 41, names: ["mark", "marcos", "mrk", "mar", "mk", "mc"] },
	{ id: 42, names: ["luke", "lucas", "luk", "lk", "lc"] },
	{ id: 62, names: ["1 john", "1 juan", "1 jn", "1jn", "1º juan", "1o juan"] },
	{ id: 63, names: ["2 john", "2 juan", "2 jn", "2jn", "2º juan", "2o juan"] },
	{ id: 64, names: ["3 john", "3 juan", "3 jn", "3jn", "3º juan", "3o juan"] },
	{ id: 43, names: ["john", "juan", "jhn", "jn"] },
	{ id: 44, names: ["acts", "hechos", "act", "hch", "hc"] },
	{ id: 45, names: ["romans", "romanos", "rom", "ro"] },
	{ id: 46, names: ["1 corinthians", "1 corintios", "1 cor", "1cor", "1 co", "1º corintios"] },
	{ id: 47, names: ["2 corinthians", "2 corintios", "2 cor", "2cor", "2 co", "2º corintios"] },
	{ id: 48, names: ["galatians", "gálatas", "galatas", "gal"] },
	{ id: 49, names: ["ephesians", "efesios", "eph", "ef"] },
	{ id: 50, names: ["philippians", "filipenses", "phil", "php", "fil"] },
	{ id: 51, names: ["colossians", "colosenses", "col"] },
	{ id: 52, names: ["1 thessalonians", "1 tesalonicenses", "1 thess", "1 tes", "1th", "1tes"] },
	{ id: 53, names: ["2 thessalonians", "2 tesalonicenses", "2 thess", "2 tes", "2th", "2tes"] },
	{ id: 54, names: ["1 timothy", "1 timoteo", "1 tim", "1tim", "1 ti"] },
	{ id: 55, names: ["2 timothy", "2 timoteo", "2 tim", "2tim", "2 ti"] },
	{ id: 56, names: ["titus", "tito", "tit", "tt"] },
	{ id: 57, names: ["philemon", "filemón", "filemon", "phlm", "phm", "flm"] },
	{ id: 58, names: ["hebrews", "hebreos", "heb"] },
	{ id: 59, names: ["james", "santiago", "jas", "stg", "st"] },
	{ id: 60, names: ["1 peter", "1 pedro", "1 pet", "1 pe", "1pe", "1ped"] },
	{ id: 61, names: ["2 peter", "2 pedro", "2 pet", "2 pe", "2pe", "2ped"] },
	{ id: 65, names: ["jude", "judas"] },
	{ id: 66, names: ["revelation", "apocalipsis", "rev", "apoc", "ap"] },
];

function fold(value: string): string {
	return String(value || "")
		.normalize("NFD")
		.replace(/[\u0300-\u036f]/g, "")
		.toLowerCase()
		.replace(/[ºª]/g, "o")
		.replace(/\s+/g, " ")
		.trim();
}

function escapeRegExp(value: string): string {
	return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

const ALIAS_TO_ID = new Map<string, number>();
const ALIASES: string[] = [];

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

const BOOK_RE = ALIASES.map((alias) => escapeRegExp(alias).replace(/ /g, "\\s+")).join("|");
const VERSE_RE = new RegExp(
	`(^|[^A-Za-z0-9ÁÉÍÓÚáéíóúÑñ])(${BOOK_RE})\\s+(\\d{1,3})\\s*:\\s*(\\d{1,3})(?:\\s*[-–—]\\s*(\\d{1,3}))?`,
	"giu"
);

const SKIP_PARENTS = "a, code, pre, .bible-verse-ref, .cm-inline-code, .internal-link, .external-link";

export function findVerseRefs(text: string): VerseHit[] {
	const hits: VerseHit[] = [];
	if (!text || text.indexOf(":") < 0) {
		return hits;
	}

	VERSE_RE.lastIndex = 0;
	let match: RegExpExecArray | null;
	while ((match = VERSE_RE.exec(text)) !== null) {
		const boundary = match[1] || "";
		const bookRaw = match[2];
		const bookId = ALIAS_TO_ID.get(fold(bookRaw));
		const chapter = Number(match[3]);
		const verse = Number(match[4]);
		const endVerse = match[5] ? Number(match[5]) : undefined;
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
			endVerse: endVerse && endVerse !== verse ? endVerse : undefined,
			from,
			to,
			text: text.slice(from, to),
		});
	}
	return hits;
}

export function verseHitFromEl(el: Element | null): VerseHit | null {
	if (!el) {
		return null;
	}
	const bookId = Number(el.getAttribute("data-book-id"));
	const chapter = Number(el.getAttribute("data-chapter"));
	const verse = Number(el.getAttribute("data-verse"));
	const endRaw = el.getAttribute("data-end-verse");
	const endVerse = endRaw ? Number(endRaw) : undefined;
	if (!bookId || !chapter || !verse) {
		return null;
	}
	return {
		bookId,
		chapter,
		verse,
		endVerse: endVerse || undefined,
		from: 0,
		to: 0,
		text: el.textContent || "",
	};
}

function applyHitAttributes(el: HTMLElement, hit: VerseHit) {
	el.classList.add("bible-verse-ref");
	el.setAttribute("data-book-id", String(hit.bookId));
	el.setAttribute("data-chapter", String(hit.chapter));
	el.setAttribute("data-verse", String(hit.verse));
	if (hit.endVerse) {
		el.setAttribute("data-end-verse", String(hit.endVerse));
	}
	el.setAttribute("title", `Open ${hit.text} in Bible Viewer`);
}

export function decorateVerseRefs(root: HTMLElement) {
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
		},
	});

	const nodes: Text[] = [];
	let current = walker.nextNode();
	while (current) {
		nodes.push(current as Text);
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
