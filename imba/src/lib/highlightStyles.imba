export const UNDERLINE_STYLES = [
	{ id: 'solid', label: 'Solid' }
	{ id: 'dotted', label: 'Dotted' }
	{ id: 'dashed', label: 'Dashed' }
	{ id: 'double', label: 'Double' }
	{ id: 'wavy', label: 'Wavy' }
]

export def normalizeColorToHex color\string
	let value = color and String(color).trim() or ''
	if value == ''
		return ''
	if value.startsWith('#')
		return value.length == 4 ? expandShortHex(value) : value
	let match = value.match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/)
	if match
		def channel n\string
			let v = Math.round(Number(n))
			return Math.max(0, Math.min(255, v)).toString(16).padStart(2, '0')
		return "#" + channel(match[1]) + channel(match[2]) + channel(match[3])
	return value

def expandShortHex hex\string
	return "#" + hex[1] + hex[1] + hex[2] + hex[2] + hex[3] + hex[3]

export def parseHighlightColor raw\string
	let value = raw and String(raw).trim() or ''
	if value == ''
		return { mode: 'none', style: 'solid', color: '' }
	if value.startsWith('u:')
		let rest = value.slice(2)
		let sep = rest.indexOf(':')
		if sep == -1
			return { mode: 'underline', style: 'solid', color: normalizeColorToHex(rest) }
		let style = rest.slice(0, sep)
		let color = normalizeColorToHex(rest.slice(sep + 1))
		return { mode: 'underline', style: style, color: color }
	return { mode: 'fill', style: 'solid', color: normalizeColorToHex(value) }

export def encodeHighlightColor mode\string, style\string, color\string
	let base = normalizeColorToHex(color)
	if mode == 'underline' and base != ''
		return "u:{style}:{base}"
	return base

export def displayHighlightColor raw\string
	let parsed = parseHighlightColor(raw)
	return parsed.color

export def underlineCss style\string, color\string
	let hex = normalizeColorToHex(color)
	if !hex
		return ''
	return "text-decoration-line: underline; text-decoration-style: {style}; text-decoration-color: {hex}; text-underline-offset: 0.14em; text-decoration-thickness: 2.5px; -webkit-text-decoration-skip-ink: none; text-decoration-skip-ink: none;"

export def highlightStyleCss raw\string, decoration\string = '', underlineStyle\string = 'solid'
	let parsed = parseHighlightColor(raw)
	let mode = decoration == 'underline' ? 'underline' : parsed.mode
	let style = decoration == 'underline' ? (underlineStyle or 'solid') : parsed.style
	let color = parsed.color or normalizeColorToHex(raw)
	if mode == 'underline' and color
		return underlineCss(style, color)
	if mode == 'fill' and color
		return "background-image: linear-gradient({color} 0px, {color} 100%); color: #000; -webkit-text-fill-color: #000;"
	return ''

export def freehandWrapOpen raw\string, decoration\string = 'fill', underlineStyle\string = 'solid'
	let parsed = parseHighlightColor(raw)
	let mode = decoration == 'underline' ? 'underline' : parsed.mode
	let style = mode == 'underline' ? (underlineStyle or parsed.style or 'solid') : parsed.style
	let color = parsed.color or normalizeColorToHex(raw)
	if mode == 'underline' and color
		return "<span style=\"{underlineCss(style, color)}\">"
	if color
		return "<mark style=\"background-color:{color}; color: #000; -webkit-text-fill-color: #000;\">"
	return '<span>'

export def freehandWrapClose raw\string, decoration\string = 'fill'
	let parsed = parseHighlightColor(raw)
	let mode = decoration == 'underline' ? 'underline' : parsed.mode
	if mode == 'underline'
		return '</span>'
	if parsed.color or raw
		return '</mark>'
	return '</span>'

export def canvasLineDash style\string
	switch style
		when 'dotted'
			return [2, 4]
		when 'dashed'
			return [7, 5]
		else
			return []

def locateTextOffset root, target
	let remaining = Number(target or 0)
	if remaining < 0
		return null
	let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
	while walker.nextNode!
		let node = walker.currentNode
		let len = (node.textContent or '').length
		if remaining <= len
			return { node: node, offset: remaining }
		remaining -= len
	return null

def highlightWrapElement raw\string, decoration\string = 'fill', underlineStyle\string = 'solid'
	let parsed = parseHighlightColor(raw)
	let mode = decoration == 'underline' ? 'underline' : parsed.mode
	let style = mode == 'underline' ? (underlineStyle or parsed.style or 'solid') : parsed.style
	let color = parsed.color or normalizeColorToHex(raw)
	if mode == 'underline'
		let el = document.createElement('span')
		el.setAttribute('style', underlineCss(style, color or '#F9E2A0'))
		return el
	if color
		let el = document.createElement('mark')
		el.setAttribute('style', "background-color:{color}; color: #000; -webkit-text-fill-color: #000;")
		return el
	return document.createElement('span')

def wrapDomTextRange root, h
	let start = Number(h.start or 0)
	let end = Number(h.end or 0)
	if !(end > start)
		return
	let a = locateTextOffset(root, start)
	let b = locateTextOffset(root, end)
	if !a
		return
	if !b
		b = locateTextOffset(root, Math.max(0, end - 1))
		if b
			b.offset = (b.node.textContent or '').length
	if !b
		return
	let range = document.createRange()
	try
		range.setStart(a.node, a.offset)
		range.setEnd(b.node, b.offset)
	catch err
		return
	if range.collapsed
		return
	let el = highlightWrapElement(h.color or '#F9E2A0', h.decoration or 'fill', h.underlineStyle or 'solid')
	try
		let contents = range.extractContents()
		el.appendChild(contents)
		range.insertNode(el)
	catch err
		try
			range.surroundContents(el)
		catch nested
			pass

export def wrapHtmlTextHighlights html, highlights
	if !html
		return html or ''
	if !highlights or highlights.length == 0
		return html
	let sorted = highlights.slice().sort(do |a, b| return Number(b.start or 0) - Number(a.start or 0))
	let host = document.createElement('div')
	host.innerHTML = html
	for h in sorted
		wrapDomTextRange(host, h)
	return host.innerHTML
