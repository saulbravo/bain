import GenericReader from '../lib/GenericReader'
import activities from '../lib/Activities'

import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import Bookmark from 'lucide-static/icons/bookmark.svg'
import X from 'lucide-static/icons/x.svg'
import * as ICONS from 'imba-phosphor-icons'

import { hasTouchEvents, translationNames } from '../constants'

tag chapter < section
	prop me\(GenericReader)
	prop headerFontSize = 2 # rem
	prop versePrefix = ''
	minHeaderFont = 0 # rem

	get main
		return document.getElementById "main"

	def calculateTopVerse e\Event
		if activities.scrollLockTimeout != null
			if activities.blockInScroll != self
				return

			clearTimeout(activities.scrollLockTimeout)

		activities.blockInScroll = self
		activities.scrollLockTimeout = setTimeout(&, 1000) do
			activities.blockInScroll = null
			activities.scrollLockTimeout = null

		let top_verse = {
			distance: -999999 # intentionally high number
			id: ''
		}

		const article = activities.blockInScroll.querySelector('article')

		unless article..children..length
			return

		for kid in article.children
			if kid.id
				let new_distance = activities.blockInScroll.scrollTop - kid.offsetTop
				if new_distance < 0 && new_distance > top_verse.distance
					top_verse.distance = new_distance
					top_verse.id = kid.id

		# TODO: implement along parallel reader
		if top_verse.id
			let verseToScrollTo = versePrefix ? top_verse.id.match(/\d+/)[0] : "p{top_verse.id}"
			reader.findVerse verseToScrollTo

	def changeHeadersSizeOnScroll e\Event
		if e.target != self
			return

		headerFontSize = 2
		minHeaderFont = 2
		if settings.parallel_sync and parallelReader.enabled
			calculateTopVerse e
		if dictionary.tooltip
			self.dictionary.showTooltip!
		imba.commit!

	def enlargeHeader
		return

	def shrinkHeader
		return

	def isMyRect matchId\string
		if activities.activeModal != ''
			return no
	
	@observable dragging = no
	currentDragHighlight = null

	def handlePointerDown e
		if activities.freehandHighlightMode
			dragging = yes
			currentDragHighlight = null

	def handlePointerUp e
		if dragging
			dragging = no
			handleFreehandHighlight(yes)
			window.getSelection().removeAllRanges()
			imba.commit!

	def handlePointerMove e
		# Don't update highlights during drag to avoid DOM re-renders destroying selection
		pass
		
	def handleFreehandHighlight isFinal = no
		return unless activities.freehandHighlightMode
		
		let selection = window.getSelection()
		if selection.isCollapsed
			if isFinal and currentDragHighlight
				currentDragHighlight = null
			return
		
		let range = selection.getRangeAt(0)
		
		# Ensure we are selecting within the article
		let article = range.startContainer.parentElement.closest('article')
		return unless article
		
		# Find the verse spans
		let startSpan = range.startContainer.parentElement.closest('span[id]')
		let endSpan = range.endContainer.parentElement.closest('span[id]')
		
		return unless startSpan and endSpan
		
		let startVerse = parseInt(startSpan.id.replace(versePrefix, ''))
		let endVerse = parseInt(endSpan.id.replace(versePrefix, ''))

		# Helper to get character offset relative to a root element, ignoring tags
		def getCharOffset node, offset, root
			let count = 0
			let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false)
			while (let next = walker.nextNode())
				if next == node
					return count + offset
				count += next.textContent.length
			return count

		let startOffset = getCharOffset(range.startContainer, range.startOffset, startSpan)
		let endOffset = getCharOffset(range.endContainer, range.endOffset, endSpan)
		
		if activities.freehandEraserMode
			# Precise erasing logic: Split or truncate highlights that overlap with the selected range
			let newHighlights = []
			let changed = false
			let sStart = startVerse * 1000000 + startOffset
			let sEnd = endVerse * 1000000 + endOffset

			for h in me.freehandHighlights
				let hStart = h.startVerse * 1000000 + h.startOffset
				let hEnd = h.endVerse * 1000000 + h.endOffset
				
				# Check if highlight 'h' overlaps with current selection [sStart, sEnd]
				if sEnd < hStart or sStart > hEnd
					# No overlap, keep the highlight as is
					newHighlights.push(h)
					continue
				
				changed = true
				
				# Part of highlight before selection
				if hStart < sStart
					newHighlights.push({
						startVerse: h.startVerse
						startOffset: h.startOffset
						endVerse: Math.floor(sStart / 1000000)
						endOffset: sStart % 1000000
						color: h.color
					})
				
				# Part of highlight after selection
				if hEnd > sEnd
					newHighlights.push({
						startVerse: Math.floor(sEnd / 1000000)
						startOffset: sEnd % 1000000
						endVerse: h.endVerse
						endOffset: h.endOffset
						color: h.color
					})
			
			if changed
				me.freehandHighlights = newHighlights
				if isFinal
					me.saveFreehandHighlights!
		else
			let highlight = {
				startVerse: startVerse
				startOffset: startOffset
				endVerse: endVerse
				endOffset: endOffset
				color: activities.freehandHighlightColor or '#eab308'
			}
			
			if currentDragHighlight
				# Replace the last temporary highlight
				me.freehandHighlights[me.freehandHighlights.length - 1] = highlight
			else
				# Start a new temporary highlight
				me.freehandHighlights.push(highlight)
			
			currentDragHighlight = highlight
			
			if isFinal
				me.saveFreehandHighlights!
				currentDragHighlight = null
		
		imba.commit!
		
		# Clear selection
		selection.removeAllRanges()
		imba.commit!
		if versePrefix == ''
			// check if there is any letter in the matchId
			return !matchId.match(/[a-zA-Z]/)
		return matchId.startsWith(versePrefix)

	def applyHighlightsToHtml html, highlights
		# Parse the HTML into a list of "parts": either a tag or a text node
		let parts = []
		let i = 0
		while i < html.length
			if html[i] == '<'
				let end = html.indexOf('>', i)
				if end != -1
					parts.push({ type: 'tag', content: html.slice(i, end + 1) })
					i = end + 1
					continue
			let nextTag = html.indexOf('<', i)
			let content = nextTag == -1 ? html.slice(i) : html.slice(i, nextTag)
			parts.push({ type: 'text', content: content })
			i += content.length

		# Sort highlights by start offset ascending
		highlights.sort(do |a, b| return a.start - b.start)

		# Helper to get contrast color (white or black) based on background hex or name
		def getContrastColor color
			return 'black' if !color
			
			# Map common CSS names to luminance values (simplified)
			const darkColors = ['FireBrick', 'RebeccaPurple', 'RoyalBlue', 'OliveDrab', 'Chocolate']
			if darkColors.includes(color)
				return 'white'
			
			if color.startsWith('#')
				let hex = color.replace('#', '')
				if hex.length == 3
					hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
				
				const r = parseInt(hex.slice(0, 2), 16)
				const g = parseInt(hex.slice(2, 4), 16)
				const b = parseInt(hex.slice(4, 6), 16)
				
				# Standard luminance calculation
				const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
				return luminance > 0.5 ? 'black' : 'white'
			
			return 'black'

		let result = ""
		let currentChar = 0
		let highlightIndex = 0
		let activeHighlights = []

		for part in parts
			if part.type == 'tag'
				result += part.content
				continue

			let text = part.content
			let textPos = 0

			while textPos < text.length
				# Check for highlights starting here
				while highlightIndex < highlights.length and highlights[highlightIndex].start == currentChar
					let h = highlights[highlightIndex]
					let textColor = getContrastColor(h.color)
					result += "<mark style=\"background-color:{h.color}; color: {textColor}\">"
					activeHighlights.push(h)
					highlightIndex++

				# Check for highlights ending here
				let highlightsEnding = activeHighlights.filter(do |h| return h.end == currentChar)
				if highlightsEnding.length > 0
					for j in [0 ... highlightsEnding.length]
						result += "</mark>"
					activeHighlights = activeHighlights.filter(do |h| return h.end != currentChar)
					
					# Re-check for new highlights starting exactly here
					while highlightIndex < highlights.length and highlights[highlightIndex].start == currentChar
						let h = highlights[highlightIndex]
						let textColor = getContrastColor(h.color)
						result += "<mark style=\"background-color:{h.color}; color: {textColor}\">"
						activeHighlights.push(h)
						highlightIndex++

				result += text[textPos]
				textPos++
				currentChar++
			
			# Check for highlights ending at the very end of a text node
			let highlightsEndingAtEnd = activeHighlights.filter(do |h| return h.end == currentChar)
			if highlightsEndingAtEnd.length > 0
				for j in [0 ... highlightsEndingAtEnd.length]
					result += "</mark>"
				activeHighlights = activeHighlights.filter(do |h| return h.end != currentChar)

		return result

	def getVerseText verse
		let verseText = verse.text
		let relevantHighlights = []
		
		for h in me.freehandHighlights
			if h.startVerse == verse.verse and h.endVerse == verse.verse
				relevantHighlights.push({ start: h.startOffset, end: h.endOffset, color: h.color })
			elif h.startVerse == verse.verse
				relevantHighlights.push({ start: h.startOffset, end: 999999, color: h.color })
			elif h.endVerse == verse.verse
				relevantHighlights.push({ start: 0, end: h.endOffset, color: h.color })
			elif h.startVerse < verse.verse and h.endVerse > verse.verse
				relevantHighlights.push({ start: 0, end: 999999, color: h.color })
		
		if relevantHighlights.length > 0
			verseText = self.applyHighlightsToHtml(verseText, relevantHighlights)
		
		return verseText

	def render
		<self .parallel=parallelReader.enabled
			@scroll.debounce(50ms)=changeHeadersSizeOnScroll
			@mousedown=handlePointerDown
			@mousemove=handlePointerMove
			@mouseup=handlePointerUp
			@touchmove=changeHeadersSizeOnScroll
			dir=translationTextDirection(me.translation)>
			<>
				for rect in pageSearch.rects when isMyRect(rect.matchID) and activities.activeModal == ''
					<.{rect.class} id=rect.matchID [pos:absolute zi:-1 top:{rect.top}px left:{rect.left}px width:{rect.width}px height:{rect.height}px]>

			if me.verses..length
				<header[zi:1] @pointerleave=shrinkHeader @pointerenter=enlargeHeader>
					<h1.header-title [lh:1 padding-block:0.2em m:0 d@md:flex ai@md:center jc@md:center ta:center w:100% font:inherit ff:{theme.fontFamily} fw:{theme.fontWeight + 200} fs:{headerFontSize}em]
						title=translationFullName(me.translation)>

						<span @click=activities.toggleBooksMenu(!!versePrefix)>
							me.nameOfCurrentBook, ' ', me.chapter

			if me.me == 'main'
				<div.tabs-sticky>
					<bible-tabs scale=1>
			<article[text-indent: {settings.verse_number ? 0 : 2.5}em] 
					data-verse-break="{settings.verse_break}"
				[mt: 30px]
					[pl: 30px]
					[pr: 30px]
					[position: relative]>
					
					# Verse selection overlay box (matches Obsidian plugin style)
					# Render if this reader has copy-select active (check per-reader PKs)
					let readerType = me.me or ''
					let hasCopySelect = false
					let startPK = 0
					if readerType == 'main'
						hasCopySelect = activities.copySelectMode and activities.copySelectStartPKMain > 0
						startPK = activities.copySelectStartPKMain
					else
						hasCopySelect = activities.copySelectMode and activities.copySelectStartPKParallel > 0
						startPK = activities.copySelectStartPKParallel
					
					if hasCopySelect
						<div.verse-selection-box>
							<button.verse-selection-insert-btn 
								@click.stop.prevent=(do
									# Get selected verses
									let selectedVerses = []
									# Use per-reader PKs
									let readerType = me.me or ''
									let startPK = readerType == 'main' ? activities.copySelectStartPKMain : activities.copySelectStartPKParallel
									let endPK = readerType == 'main' ? activities.copySelectEndPKMain : activities.copySelectEndPKParallel
									
									let startIdx = me.verses.findIndex(do |v| return v.pk == startPK)
									let endIdx = me.verses.findIndex(do |v| return v.pk == endPK)
									if startIdx != -1 and endIdx != -1
										let minIdx = Math.min(startIdx, endIdx)
										let maxIdx = Math.max(startIdx, endIdx)
										for i in [minIdx .. maxIdx]
											if me.verses[i]
												let verse = me.verses[i]
												let reference = "{me.nameOfCurrentBook} {me.chapter}:{verse.verse}"
												selectedVerses.push({
													reference: reference,
													text: verse.text,
													verse: verse.verse
												})
									
									# Send message to parent window (Obsidian) if in iframe
									# Always try to send if we have verses - let the parent decide if it wants to handle it
									if selectedVerses.length > 0
										# Include translation, book, and chapter info for building the URL
										# Make sure all fields are explicitly set
										let translationCode = me.translation || ''
										let bookName = me.nameOfCurrentBook || ''
										let chapterNum = me.chapter || 1
										let bookIdNum = me.book || 1
										
										# Create message data object with explicit values - ensure all are set
										# Use object literal to ensure proper serialization
										let messageData = {
													type: 'bible-verse-selection',
											verses: selectedVerses,
											translation: translationCode,
											book: bookName,
											chapter: chapterNum,
											bookId: bookIdNum
										}
										
										# Always try to send - let the parent decide if it wants to handle it
										# Use structuredClone or JSON serialization to ensure all properties are included
										try
											# Create a plain object that will serialize correctly
											let messageToSend = {
												type: String(messageData.type),
												verses: Array.from(messageData.verses),
												translation: String(messageData.translation),
												book: String(messageData.book),
												chapter: Number(messageData.chapter),
												bookId: Number(messageData.bookId)
											}
											window.parent.postMessage(messageToSend, '*')
										catch error
											pass
										# Try sending with JSON serialization as fallback
										try
											let jsonMessage = JSON.parse(JSON.stringify(messageData))
											window.parent.postMessage(jsonMessage, '*')
										catch fallbackError
											pass
								)>
									<svg src=ChevronLeft>
							<button.verse-selection-close-btn 
								@click.stop.prevent=(do
									let readerType = me.me or ''
									
									# Only clear this reader's copy-select, keep the other reader's if it exists
									if readerType == 'main'
										activities.copySelectStartPKMain = 0
										activities.copySelectEndPKMain = 0
										# Clear global PKs only if parallel doesn't have active copy-select
										if activities.copySelectStartPKParallel == 0
											activities.copySelectStartPK = 0
											activities.copySelectEndPK = 0
											activities.copySelectedVersesPKs = []
											activities.copySelectModeReader = null
									else
										activities.copySelectStartPKParallel = 0
										activities.copySelectEndPKParallel = 0
										# Clear global PKs only if main doesn't have active copy-select
										if activities.copySelectStartPKMain == 0
											activities.copySelectStartPK = 0
											activities.copySelectEndPK = 0
											activities.copySelectedVersesPKs = []
											activities.copySelectModeReader = null
									
									imba.commit!
									me.updateCopySelectRange!
								)>
									<svg src=X>
							<span.verse-selection-handle.verse-selection-handle-top 
								@mousedown.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'top'; activities.copySelectReader = me)
								@touchstart.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'top'; activities.copySelectReader = me)>
							<span.verse-selection-handle.verse-selection-handle-bottom 
								@mousedown.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'bottom'; activities.copySelectReader = me)
								@touchstart.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'bottom'; activities.copySelectReader = me)>
					
					for verse, verse_index in me.verses
						let bookmark = me.getBookmark(verse.pk, 'bookmarks')
						let superStyle = "padding-bottom:{0.8 * theme.lineHeight}em;padding-top:{theme.lineHeight - 1}em;scroll-margin-top:1.4rem;"
						let verseText = getVerseText(verse)

						<>
							<span 
								.selected-verse=(activities.selectedVersesPKs.includes(verse.pk)) 
								[background-image: {me.getHighlight(verse.pk)}]
								[color: {activities.selectedVersesPKs.includes(verse.pk) ? null : me.getHighlightTextColor(verse.pk)}]>
								
								if settings.verse_number
									unless settings.verse_break
										<span> ' '
									<span.verse dir="ltr" style=superStyle @click=(me.findVerse("{versePrefix}{verse.verse}"))>
										if settings.verse_break then '\u2007' else'\u2007\u2007\u2007'
										verse.verse
										"\u2007"
								else
									unless settings.verse_break
										<span> ' '
								
								<span innerHTML=verseText
									id="{versePrefix}{verse.verse}"
									@click.wait(200ms)=(do
										console.log('[DEBUG] Verse clicked in chapter view:', { pk: verse.pk, verse: verse.verse, prefix: versePrefix })
										me.selectVerse(verse.pk, verse.verse)
									)
									# make it focus-able to get keydown working on it
									tabIndex=0
									@keydown.enter=me.saveBookmark
									[scroll-margin-top: 1.4rem]
								>
							if bookmark and not me.nextVerseHasTheSameBookmark(verse_index) and (bookmark.collection || bookmark.note)
								<note-tooltip style=superStyle bookmark=bookmark>
									<svg src=Bookmark>
										<title> bookmark.collection + ': ' + bookmark.note

							if verse.comment and settings.verse_commentary
								<note-tooltip style=superStyle bookmark=verse.comment>
									<span[c:$acc @hover:$acc-hover]> '†'

							if settings.verse_break
								<br>
								unless settings.verse_number
									<span.ws> '	'
				
			if !me.verses..length
				if !window.navigator.onLine && vault.downloaded_translations.indexOf(me.translation) == -1
					<p.in-offline>
						t.this_translation_is_unavailable
						<br>
						<a.reload @click=(do window.location.reload(yes))> t.reload
				elif not me.loading
					<p.in-offline>
						t.unexisten_chapter
						<br>
						<a.reload @click=(do window.location.reload(yes))> t.reload

			if me.show_verse_picker and settings.verse_picker then <global>
				<section[origin:top left scale@off:0.96 y@off:-1rem o@off:0] ease>
					css
						pos: fixed
						t:3rem l:3rem
						rd:.5rem
						zi:100
						bgc:$bgc
						w:18.75rem mah:86%
						p:.75rem
						rd:1rem
						ofy:auto
						bxs: 0 0 0 1px $acc-bgc-hover, 0 3px 6px $acc-bgc-hover, 0 9px 24px $acc-bgc-hover

						a
							cursor:pointer
							d:inline-block ta:center
							c@hover:$acc-hover
							h:3.375rem w:20%
							fs:1.25rem pt:1rem
							pos:relative

					<[d:flex ai:center]>
						<h2[margin:0 auto lh:1]> t.choose_verse
						<button[c@hover:red4 size:2rem p:.25rem] @click=(me.show_verse_picker=no) title=t.close>
							<svg src=ICONS.X aria-hidden=yes>
					for verse in me.verses
						<a href="#{versePrefix}{verse.verse}"> verse.verse


	css
		mah: 100vh
		overflow-y: auto
		w:100% max-width:100%
		pos:relative

		h1
			text-align: center
			margin: 1em 0
			padding: 0
			position: sticky
			background-color: $bgc
			top: 0
			line-height: 1
			cursor: pointer
			word-break: break-word
			padding-inline: 0.25rem

		header
			position: static
			background-color: $bgc
			margin: 0
			padding-top: 1rem
			ta: center
			height: auto

		.header-title
			margin: 0
			overflow: hidden

		.tabs-sticky
			position: sticky
			top: 0
			zi: 2
			bgc: $bgc
			padding-top: 1rem
			w: 100%
			max-width: 100%
			min-width: 0
			box-sizing: border-box
			overflow-x: hidden

		section .arrowh
			transition-property: fill, color, background, transform, border-radius

		span
			background-size: 100% 100%
			padding-bottom: .25rem

		.verse
			fs: 0.68em
			c: $acc @hover:$acc-hover
			bgc@hover:$acc-bgc-hover
			vertical-align: super
			white-space: pre
			border-radius: 0.25rem

		note-tooltip svg
			c:$acc @hover:$acc-hover
			size:0.68em

		.reload
			display: block
			mt:.5rem
			w: 100%
			cursor: pointer
			text-decoration: solid underline
			y@hover:-2px

		.selected-verse
			c@important: $acc
			background: none
			background-image: none
			background-color: transparent
		
		span.selected-verse::selection,
		span.selected-verse::-moz-selection
			background-color: transparent
			color: $acc

		# Verse selection overlay box (matches Obsidian plugin style)
		.verse-selection-box
			position: absolute
			left: 0
			right: 0
			border-radius: 8px
			background: color-mix(in srgb, #a855f7 15%, transparent)
			border: 2px solid #a855f7
			z-index: 5
			pointer-events: none
			transition: top 150ms ease, height 150ms ease
			display: none
			padding-left: 20px
			padding-right: 20px

		.verse-selection-box[style*="display: block"]
			display: block

		# Insert button inside selection box
		.verse-selection-insert-btn
			position: absolute
			left: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 6px 0 0 6px
			display: flex
			align-items: center
			justify-content: center
			cursor: pointer
			pointer-events: auto
			transition: all 0.15s ease
			background@hover: #9333ea
			opacity@hover: 0.8
			background@active: #9333ea
			opacity@active: 0.7
			box-sizing: border-box
			padding: 0
			margin: 0
			overflow: hidden

		.verse-selection-insert-btn svg
			width: 14px
			height: 14px
			color: white
			display: block
			flex-shrink: 0
			margin: 0 auto
			position: relative

		# Close button inside selection box (on the right)
		.verse-selection-close-btn
			position: absolute
			right: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 0 6px 6px 0
			display: flex
			align-items: center
			justify-content: center
			cursor: pointer
			pointer-events: auto
			transition: all 0.15s ease
			background@hover: #9333ea
			opacity@hover: 0.8
			background@active: #9333ea
			opacity@active: 0.7
			box-sizing: border-box
			padding: 0
			margin: 0
			overflow: hidden

		.verse-selection-close-btn svg
			width: 14px
			height: 14px
			color: white
			display: block
			flex-shrink: 0
			margin: 0
			padding: 0
			position: relative

		# Drag handles
		.verse-selection-handle
			position: absolute
			left: 50%
			transform: translateX(-50%)
			width: 64px
			height: 6px
			border-radius: 999px
			background: #a855f7
			cursor: ns-resize
			pointer-events: auto
			z-index: 6
			# ensure it stays visually centered on the box border
			margin-left: 0

		.verse-selection-handle-top
			top: -4px

		.verse-selection-handle-bottom
			bottom: -4px

		html[data-copy-select-dragging="true"] .verse-selection-box
			transition: none

		.in-offline
			padding: 2rem
			text-align: center