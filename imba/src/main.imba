import './lib'
import activities from './lib/Activities'
import './global.css'
import './routes'
import * as Sentry from "@sentry/browser";

# Listen for cache clearing messages from parent (e.g., Obsidian plugin)
# But don't do anything - the cache-busting URL parameters should be enough
# Removing automatic cache clearing to prevent reload loops
def isTrustedParentMessage event
	if event.source == window.parent
		return yes
	if !event.origin
		return no
	if event.origin.includes('localhost') or event.origin.includes('127.0.0.1') or event.origin == window.location.origin
		return yes
	if event.origin.includes('obsidian.md') or event.origin.startsWith('app://')
		return yes
	return no

window.addEventListener('message', do |event|
	unless isTrustedParentMessage(event)
		return
	unless event.data
		return
	# Only accept messages from same origin or localhost
	if event.data.type == 'clear-cache' and event.data.force
		console.log('Bible App: Received clear-cache message (ignoring to prevent reload loops)')
		# Just log - don't actually clear cache or reload
		# The cache-busting URL parameters should be sufficient
	elif event.data.type == 'unregister-sw' and event.data.force
		console.log('Bible App: Received unregister-sw message (ignoring to prevent reload loops)')
		# Just log - don't actually unregister
	elif event.data.type == 'bible-verse-linked'
		activities.recordVerseNoteLink(event.data)
)

tag app
	def mount
		Sentry.init({
			dsn: "https://5a69d00bbc564998800e91e75162e31b@o4509977736118272.ingest.de.sentry.io/4509977739984976",
			// Setting this option to true will send default PII data to Sentry.
			// For example, automatic IP address collection on events
			sendDefaultPii: true
		})

	get cursorSvg
		let color = activities.freehandEraserMode ? '#777777' : (activities.freehandHighlightColor or '#eab308')
		if activities.penToolMode
			let dot = activities.penEraserMode ? '#777777' : (activities.freehandHighlightColor or '#000000')
			let encodedDot = dot.startsWith('#') ? "%23{dot.slice(1)}" : dot
			let radius = Math.max(2, Math.min(10, ((activities.penLineWidth or 3) * 0.7)))
			let dotSvg = "<svg width='24' height='24' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'><circle cx='12' cy='12' r='{radius}' fill='{encodedDot}'/></svg>"
			return "url(\"data:image/svg+xml;utf8,{dotSvg}\") 12 12, auto"
		# URL encode the hex color if it starts with #
		let encodedColor = color.startsWith('#') ? "%23{color.slice(1)}" : color
		let svg = "<svg width='24' height='24' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'><circle cx='12' cy='12' r='9' stroke='{encodedColor}' stroke-width='2'/><circle cx='12' cy='12' r='11' stroke='rgba(0,0,0,0.2)' stroke-width='1'/></svg>"
		return "url(\"data:image/svg+xml;utf8,{svg}\") 12 12, auto"

	get selectionTextColor
		return 'black'

	<self>
		if activities.freehandHighlightMode or activities.penToolMode
			<style> "
				body, body * \{ cursor: {cursorSvg} !important; \}
				button, a, svg, .chevron, [role='button'], .color-option, .action-button, header, header *, .arrow \{ cursor: pointer !important; \}
				freehand-highlight-menu, freehand-highlight-menu * \{ cursor: default !important; \}
				freehand-highlight-menu button, freehand-highlight-menu svg, freehand-highlight-menu [role='button'], freehand-highlight-menu .color-option, freehand-highlight-menu .underline-option, freehand-highlight-menu .tab, freehand-highlight-menu .chevron, freehand-highlight-menu input \{ cursor: pointer !important; \}
				freehand-highlight-menu button[disabled] \{ cursor: not-allowed !important; \}
			"
		if activities.freehandHighlightMode or activities.penToolMode
			<style> "
				/* Hide native text-selection paint during freehand drag; show only custom stroke preview. */
				*::selection \{ background-color: transparent !important; color: inherit !important; \}
				*::-moz-selection \{ background-color: transparent !important; color: inherit !important; \}
			"
		if activities.penToolMode
			<style> "
				article, article * \{ user-select: none !important; -webkit-user-select: none !important; \}
			"
		<html .freehand-mode=activities.freehandHighlightMode .pen-mode=activities.penToolMode .eraser-mode=activities.freehandEraserMode [--freehand-color:{activities.freehandHighlightColor}]>
		<profile route='/profile/'>
		<downloads route='/downloads/'>
		<donate route='/donate/'>

		<reader route='/international/:translation/:book/:chapter'>
		<reader route='/:translation/:book/:chapter'>
		<reader route='/*'>

		<notifications>
		if activities.freehandHighlightMode or activities.penToolMode
			<freehand-highlight-menu>


imba.mount <app>
