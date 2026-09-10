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

export def cssColorToRgb color\string
	let value = color and String(color).trim() or ''
	if value == ''
		return null
	let hex = normalizeColorToHex(value)
	if hex and hex[0] == '#'
		if hex.length == 4
			hex = expandShortHex(hex)
		if hex.length >= 7
			let r = Number.parseInt(hex.slice(1, 3), 16)
			let g = Number.parseInt(hex.slice(3, 5), 16)
			let b = Number.parseInt(hex.slice(5, 7), 16)
			if r == r and g == g and b == b
				return { r: r, g: g, b: b }
	if typeof document == 'undefined'
		return null
	let probe = document.createElement('span')
	probe.style.color = value
	document.documentElement.appendChild(probe)
	let computed = window.getComputedStyle(probe).color
	probe.parentNode.removeChild(probe)
	let match = String(computed or '').match(/rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/)
	if !match
		return null
	return {
		r: Math.round(Number(match[1]))
		g: Math.round(Number(match[2]))
		b: Math.round(Number(match[3]))
	}

def relativeLuminance rgb
	unless rgb
		return 0
	def channel n
		let c = n / 255
		if c <= 0.03928
			return c / 12.92
		return Math.pow((c + 0.055) / 1.055, 2.4)
	return 0.2126 * channel(rgb.r) + 0.7152 * channel(rgb.g) + 0.0722 * channel(rgb.b)

export def contrastRatio a, b
	let l1 = relativeLuminance(a)
	let l2 = relativeLuminance(b)
	let hi = Math.max(l1, l2)
	let lo = Math.min(l1, l2)
	return (hi + 0.05) / (lo + 0.05)

export def contrastTextForColor raw\string
	let rgb = cssColorToRgb(raw)
	if !rgb
		return '#000000'
	if relativeLuminance(rgb) < 0.45
		return '#ffffff'
	return '#000000'

def mixRgb a, b, t
	return {
		r: Math.round(a.r + (b.r - a.r) * t)
		g: Math.round(a.g + (b.g - a.g) * t)
		b: Math.round(a.b + (b.b - a.b) * t)
	}

def rgbToHex rgb
	def hex n
		let v = Math.max(0, Math.min(255, Math.round(n)))
		return v.toString(16).padStart(2, '0')
	return "#{hex(rgb.r)}{hex(rgb.g)}{hex(rgb.b)}"

export def accentSelectColor
	if typeof document == 'undefined'
		return ''
	return String(window.getComputedStyle(document.documentElement).getPropertyValue('--acc') or '').trim()

export def selectionTextColorForHighlight highlightColor\string
	let accent = accentSelectColor!
	let bg = cssColorToRgb(highlightColor)
	let acc = cssColorToRgb(accent)
	unless bg
		return accent or '#ffffff'
	unless acc
		return contrastTextForColor(highlightColor)
	if contrastRatio(acc, bg) >= 4.5
		return accent
	# Keep the select color family, but push it toward black or white until
	# it is readable on this highlight (gold-on-yellow becomes dark gold).
	let black = { r: 0, g: 0, b: 0 }
	let white = { r: 255, g: 255, b: 255 }
	let step = 1
	while step <= 12
		let t = step / 12
		let darker = mixRgb(acc, black, t)
		if contrastRatio(darker, bg) >= 4.5
			return rgbToHex(darker)
		let lighter = mixRgb(acc, white, t)
		if contrastRatio(lighter, bg) >= 4.5
			return rgbToHex(lighter)
		step++
	return contrastTextForColor(highlightColor)

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

export def freehandWrapOpen raw\string, decoration\string = 'fill', underlineStyle\string = 'solid', textColor\string = '#000', selected = no
	let parsed = parseHighlightColor(raw)
	let mode = decoration == 'underline' ? 'underline' : parsed.mode
	let style = mode == 'underline' ? (underlineStyle or parsed.style or 'solid') : parsed.style
	let color = parsed.color or normalizeColorToHex(raw)
	if mode == 'underline' and color
		return "<span style=\"{underlineCss(style, color)}\">"
	if color
		let fillText = textColor or '#000'
		let fillBg = color
		if selected
			fillBg = "color-mix(in srgb, {color} 78%, #000000)"
		let important = selected ? ' !important' : ''
		return "<mark style=\"background-color:{fillBg}; color: {fillText}{important}; -webkit-text-fill-color: {fillText}{important};\">"
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
	# Wrap each text node in place. Range.extractContents can pull a <mark>
	# out of a <p> (or empty the paragraph), which inserts a new block and
	# shoves the commentary text down on the first highlight after load.
	let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
	let segments = []
	let consumed = 0
	while walker.nextNode!
		let node = walker.currentNode
		let parent = node.parentNode
		let len = (node.textContent or '').length
		let nodeStart = consumed
		consumed += len
		if !parent
			continue
		if parent == root and String(node.textContent or '').trim() == ''
			continue
		if consumed <= start or nodeStart >= end
			continue
		let localStart = Math.max(0, start - nodeStart)
		let localEnd = Math.min(len, end - nodeStart)
		if localEnd > localStart
			segments.push({
				node: node
				start: localStart
				end: localEnd
			})
	let idx = segments.length - 1
	while idx >= 0
		let seg = segments[idx]
		let node = seg.node
		unless node and node.parentNode
			idx -= 1
			continue
		let textLen = (node.textContent or '').length
		if seg.end < textLen
			node.splitText(seg.end)
		let target = node
		if seg.start > 0
			target = node.splitText(seg.start)
		unless target and target.textContent
			idx -= 1
			continue
		let el = highlightWrapElement(h.color or '#F9E2A0', h.decoration or 'fill', h.underlineStyle or 'solid')
		target.parentNode.insertBefore(el, target)
		el.appendChild(target)
		idx -= 1

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
