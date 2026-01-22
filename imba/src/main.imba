import './lib'
import './global.css'
import './routes'
import * as Sentry from "@sentry/browser";

# Listen for cache clearing messages from parent (e.g., Obsidian plugin)
window.addEventListener('message', do |event|
	# Only accept messages from same origin or localhost
	if event.origin.includes('localhost') or event.origin.includes('127.0.0.1') or event.origin == window.location.origin
		if event.data?.type == 'clear-cache' and event.data?.force
			console.log('Bible App: Received clear-cache message, clearing service worker cache')
			# Unregister service worker first
			if 'serviceWorker' in navigator
				navigator.serviceWorker.getRegistrations().then(do |registrations|
					Promise.all(registrations.map(do |registration|
						registration.unregister()
					))
				).then(do
					console.log('Bible App: Service workers unregistered')
					# Clear all caches
					if 'caches' in window
						caches.keys().then(do |cacheNames|
							Promise.all(cacheNames.map(do |cacheName|
								caches.delete(cacheName)
							))
						).then(do
							console.log('Bible App: All caches cleared')
							# Reload the page to get fresh content
							window.location.reload()
						)
					else
						window.location.reload()
				)
			else
				# No service worker, just clear caches
				if 'caches' in window
					caches.keys().then(do |cacheNames|
						Promise.all(cacheNames.map(do |cacheName|
							caches.delete(cacheName)
						))
					).then(do
						console.log('Bible App: All caches cleared')
						window.location.reload()
					)
		elif event.data?.type == 'unregister-sw' and event.data?.force
			console.log('Bible App: Received unregister-sw message')
			if 'serviceWorker' in navigator
				navigator.serviceWorker.getRegistrations().then(do |registrations|
					Promise.all(registrations.map(do |registration|
						registration.unregister()
					))
				).then(do
					console.log('Bible App: Service workers unregistered')
					window.location.reload()
				)
)

tag app
	def mount
		Sentry.init({
			dsn: "https://5a69d00bbc564998800e91e75162e31b@o4509977736118272.ingest.de.sentry.io/4509977739984976",
			// Setting this option to true will send default PII data to Sentry.
			// For example, automatic IP address collection on events
			sendDefaultPii: true
		})

	<self>
		<profile route='/profile/'>
		<downloads route='/downloads/'>
		<donate route='/donate/'>

		<reader route='/international/:translation/:book/:chapter'>
		<reader route='/:translation/:book/:chapter'>
		<reader route='/*'>

		<notifications>


imba.mount <app>
