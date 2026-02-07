import './lib'
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

	@observable cursorPos = { x: 0, y: 0 }

	def handlePointerMove e
		if activities.freehandHighlightMode
			cursorPos.x = e.clientX
			cursorPos.y = e.clientY
			imba.commit!

	<self @pointermove=handlePointerMove>
		<global [cursor:none]=activities.freehandHighlightMode>
		<html .freehand-mode=activities.freehandHighlightMode [--freehand-color:{activities.freehandHighlightColor}]>
		<profile route='/profile/'>
		<downloads route='/downloads/'>
		<donate route='/donate/'>

		<reader route='/international/:translation/:book/:chapter'>
		<reader route='/:translation/:book/:chapter'>
		<reader route='/*'>

		<notifications>
		<freehand-highlight-menu>
		
		<div.freehand-cursor [l:{cursorPos.x}px t:{cursorPos.y}px bd:2px solid {activities.freehandHighlightColor}]>


imba.mount <app>
