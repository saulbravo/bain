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
	let localized = String(html).replace(/([A-Za-z0-9]+)_(\d+):(\d+(?:-\d+)?)/g, do(match, code, chapter, verses)
		const bookid = CBA_BOOK_CODES[code]
		if !bookid
			return match
		const bookName = getBookName(translation, bookid)
		return "{bookName} {chapter}:{verses}"
	)
	return cleanCommentaryHtml(localized)

export def cleanCommentaryHtml html\string
	if !html
		return html or ''
	return String(html).replace(/<p class="cba-heading">\[/g, '<p class="cba-heading">')

export def htmlToPlainText html\string
	if !html
		return ''
	let el = document.createElement('div')
	el.innerHTML = html
	return (el.textContent or el.innerText or '').replace(/\n{3,}/g, '\n\n').trim()

export def escapeHtml text\string
	return String(text or '')
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')

export def splitPlainTextToParagraphs text\string
	if !text
		return []
	let normalized = String(text).replace(/\r\n/g, '\n').replace(/\r/g, '\n')
	normalized = normalized.replace(/\n{3,}/g, '\n\n').trim()
	let paragraphs = []
	for block in normalized.split(/\n\n+/)
		block = block.trim()
		if !block or block == 'Comentario Bíblico Adventista'
			continue
		for part in block.split(/\n(?=\s{2,})/)
			part = part.replace(/^[\t ]+/gm, '').trim()
			if part
				paragraphs.push(part)
	return paragraphs

export def splitCommentaryHtmlIntoBlocks html\string, fallbackText\string = ''
	let blocks = []
	if html
		let wrapper = document.createElement('div')
		wrapper.innerHTML = html
		let paras = wrapper.querySelectorAll('p')
		if paras and paras.length > 0
			for i in [0 .. paras.length - 1]
				let p = paras[i]
				let text = String(p.textContent or '').trim()
				if !text
					continue
				blocks.push({ html: p.outerHTML, text: text })
			if blocks.length > 0
				return blocks
	let parts = splitPlainTextToParagraphs(fallbackText or htmlToPlainText(html))
	for part in parts
		let safe = escapeHtml(part).replace(/\n/g, '<br>')
		blocks.push({ html: "<p>{safe}</p>", text: part })
	return blocks

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
