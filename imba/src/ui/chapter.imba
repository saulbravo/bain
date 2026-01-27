import GenericReader from '../lib/GenericReader'

import ChevronRight from 'lucide-static/icons/chevron-right.svg'
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

		let testSize = 2 - ((e.target.scrollTop * 8) / window.innerHeight)
		if testSize * theme.fontSize < 12
			headerFontSize = 16 / theme.fontSize
		elif e.target.scrollTop > 0
			headerFontSize = testSize
		else
			headerFontSize = 2

		unless versePrefix
			const last_known_scroll_position = e.target.scrollTop
			setTimeout(&, 100) do
				if e.target.scrollTop < last_known_scroll_position || not e.target.scrollTop
					activities.menuIconsTransform = 0
				elif e.target.scrollTop > last_known_scroll_position
					if window.innerWidth >= 1024
						activities.menuIconsTransform = -100
					else
						activities.menuIconsTransform = 100

		if settings.parallel_sync and parallelReader.enabled
			calculateTopVerse e
		if dictionary.tooltip
			# recalculate tooltip position
			self.dictionary.showTooltip!
		imba.commit!

	def enlargeHeader
		unless hasTouchEvents
			minHeaderFont = 1.2

	def shrinkHeader
		minHeaderFont = 0

	# no -- means prev, yes -- means next
	def getChevron direction\boolean
		const textDirection = translationTextDirection(me.translation)
		if (textDirection == 'rtl' && direction) or (textDirection == 'ltr' && !direction)
			return <svg src=ChevronLeft aria-label=t.prev> 
		return <svg src=ChevronRight aria-label=t.next>
	
	def isMyRect matchId\string
		if activities.activeModal != ''
			return no
		if versePrefix == ''
			// check if there is any letter in the matchId
			return !matchId.match(/[a-zA-Z]/)
		return matchId.startsWith(versePrefix)

	def render
		<self .parallel=parallelReader.enabled
			@scroll.debounce(50ms)=changeHeadersSizeOnScroll
			@touchmove=changeHeadersSizeOnScroll
			dir=translationTextDirection(me.translation)>
			<>
				for rect in pageSearch.rects when isMyRect(rect.matchID) and activities.activeModal == ''
					<.{rect.class} id=rect.matchID [pos:absolute zi:-1 top:{rect.top}px left:{rect.left}px width:{rect.width}px height:{rect.height}px]>

			if me.verses..length
				<header[h:0 margin-block:min(4em, 8vw) zi:1] @click=activities.toggleBooksMenu(!!versePrefix)  @pointerleave=shrinkHeader @pointerenter=enlargeHeader>
					#main_header_arrow_size = "min(64px, max({minHeaderFont}em, {headerFontSize}em))"
					<h1
						[lh:1 padding-block:0.2em m:0 d@md:flex ai@md:center jc@md:space-between font:inherit ff:{theme.fontFamily} fw:{theme.fontWeight + 200} fs:max({minHeaderFont}em, min({headerFontSize}em, 8vw))]
						title=translationFullName(me.translation)>

						<a.arrow @click.prevent.stop=me.prevChapter [d@lt-md:none max-height:{#main_header_arrow_size} max-width:{#main_header_arrow_size} min-height:{#main_header_arrow_size} min-width:{#main_header_arrow_size}] title=t.prev href="{me.prevChapterLink}">
							getChevron(no)

						me.nameOfCurrentBook, ' ', me.chapter

						<a.arrow @click.prevent.stop=me.nextChapter [d@lt-md:none max-height:{#main_header_arrow_size} max-width:{#main_header_arrow_size} min-height:{#main_header_arrow_size} min-width:{#main_header_arrow_size}] title=t.next href=me.nextChapterLink>
							getChevron(yes)

				<p[padding-inline:.5rem o:0 lh:1 ff:{theme.fontFamily} fw:{theme.fontWeight + 200} fs:min({theme.fontSize * 2}px, 8vw) us:none word-break:break-word]> me.nameOfCurrentBook, ' ', me.chapter # since header height is changing, this takes constant space for header to avoid layout shifts
				<article[text-indent: {settings.verse_number ? 0 : 2.5}em] 
					data-verse-break="{settings.verse_break}"
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

						<span 
							.selected-verse=(activities.selectedVersesPKs.includes(verse.pk)) 
							[background-image: {me.getHighlight(verse.pk)}]>
							
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
							<span innerHTML=verse.text
									id="{versePrefix}{verse.verse}"
									@click.wait(200ms)=me.selectVerse(verse.pk, verse.verse)
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
				
				<[d:hcs p:1.5rem .5rem 6rem overflow:hidden]>
					<a.arrow [s:4rem] @click.prevent.stop=me.prevChapter title=t.prev href=me.prevChapterLink>
						getChevron(no)
					<a.arrow [s:4rem] @click.prevent.stop=me.nextChapter title=t.next href=me.nextChapterLink>
						getChevron(yes)

			elif !window.navigator.onLine && vault.downloaded_translations.indexOf(me.translation) == -1
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

		h1, header
			text-align: center
			margin: 1em 0
			padding: 0
			position: sticky
			background-color: $bgc
			top: 0
			line-height: 1
			cursor: pointer
			word-break: break-word

		h1
			padding-inline: 0.25rem

		header
			position: sticky
			top: 0
			background-color: $bgc
			margin: 1em 0

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

		.arrow
			c:inherit
			bgc@hover:$acc-bgc-hover
			rd@hover:50%
			transform@hover:rotate(360deg)
			d:hcc

			svg
				max-height: 100%
				max-width: 100%

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
			c: $acc
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