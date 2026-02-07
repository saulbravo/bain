import './lib'
import activities from './lib/Activities'
import './global.css'
import './routes'
import * as Sentry from "@sentry/browser";

# Listen for cache clearing messages from parent (e.g., Obsidian plugin)
# But don't do anything - the cache-busting URL parameters should be enough
# Removing automatic cache clearing to prevent reload loops
window.addEventListener('message', do |event|
	# Only accept messages from same origin or localhost
	if event.origin.includes('localhost') or event.origin.includes('127.0.0.1') or event.origin == window.location.origin
		if event.data?.type == 'clear-cache' and event.data?.force
			console.log('Bible App: Received clear-cache message (ignoring to prevent reload loops)')
			# Just log - don't actually clear cache or reload
			# The cache-busting URL parameters should be sufficient
		elif event.data?.type == 'unregister-sw' and event.data?.force
			console.log('Bible App: Received unregister-sw message (ignoring to prevent reload loops)')
			# Just log - don't actually unregister
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
		let color = activities.freehandEraserMode ? 'red' : (activities.freehandHighlightColor or '#eab308')
		# URL encode the hex color if it starts with #
		let encodedColor = color.startsWith('#') ? "%23{color.slice(1)}" : color
		let svg = "<svg width='24' height='24' viewBox='0 0 24 24' fill='none' xmlns='http://www.w3.org/2000/svg'><circle cx='12' cy='12' r='9' stroke='{encodedColor}' stroke-width='2'/><circle cx='12' cy='12' r='11' stroke='rgba(0,0,0,0.2)' stroke-width='1'/></svg>"
		return "url(\"data:image/svg+xml;utf8,{svg}\") 12 12, auto"

	<self>
		if activities.freehandHighlightMode or activities.freehandEraserMode
			<style> "
				article, article * \{ cursor: {cursorSvg} !important; \}
				button, a, svg, .chevron, [role='button'], .color-option, .action-button, header, header *, .arrow \{ cursor: pointer !important; \}
				freehand-highlight-menu \{ cursor: auto; \}
				*::selection \{ background-color: {activities.freehandHighlightColor} !important; color: inherit !important; \}
				*::-moz-selection \{ background-color: {activities.freehandHighlightColor} !important; color: inherit !important; \}
			"
		<html .freehand-mode=activities.freehandHighlightMode .eraser-mode=activities.freehandEraserMode [--freehand-color:{activities.freehandHighlightColor}]>
		<profile route='/profile/'>
		<downloads route='/downloads/'>
		<donate route='/donate/'>

		<reader route='/international/:translation/:book/:chapter'>
		<reader route='/:translation/:book/:chapter'>
		<reader route='/*'>

		<notifications>
		<freehand-highlight-menu>


imba.mount <app>
