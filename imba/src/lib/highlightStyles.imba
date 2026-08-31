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
