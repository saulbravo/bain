import { getBookName } from './index'

const CBA_BOOK_CODES = {
	Gen: 1, Exo: 2, Lev: 3, Num: 4, Deu: 5, Jos: 6, Jdg: 7, Rht: 8,
	'1Sa': 9, '2Sa': 10, '1Ki': 11, '2Ki': 12, '1Ch': 13, '2Ch': 14,
	Ezr: 15, Neh: 16, Est: 17, Job: 18, Psa: 19, Pro: 20, Ecc: 21, Son: 22,
	Isa: 23, Jer: 24, Lam: 25, Eze: 26, Dan: 27, Hos: 28, Joe: 29, Amo: 30,
	Oba: 31, Jon: 32, Miq: 33, Mic: 33, Nah: 34, Hab: 35, Zep: 36, Hag: 37,
	Zec: 38, Mal: 39, Mat: 40, Mar: 41, Mrk: 41, Luk: 42, Joh: 43, Act: 44,
	Rom: 45, '1Co': 46, '2Co': 47, Gal: 48, Eph: 49, Phi: 50, Col: 51,
	'1Th': 52, '2Th': 53, '1Ti': 54, '2Ti': 55, Tit: 56, Phm: 57, Heb: 58,
	Jam: 59, '1Pe': 60, '2Pe': 61, '1Jo': 62, '2Jo': 63, '3Jo': 64, Jud: 65,
	Rev: 66,
}

export def localizeCommentaryRefs html\string, translation\string
	if !html or !translation
		return html or ''
	return String(html).replace(/([A-Za-z0-9]+)_(\d+):(\d+(?:-\d+)?)/g, do(match, code, chapter, verses)
		const bookid = CBA_BOOK_CODES[code]
		if !bookid
			return match
		const bookName = getBookName(translation, bookid)
		return "{bookName} {chapter}:{verses}"
	)

export def localizedBookAbbreviation book\object, showFull\boolean = no
	if !book or !book.name
		return '???'
	if showFull
		return book.name
	let name = String(book.name).trim()
	let numbered = name.match(/^(\d+)\s+(.+)$/)
	if numbered
		return "{numbered[1]} {numbered[2].slice(0, 3)}"
	return name.slice(0, 3)
