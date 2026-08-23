import '../ui'
import '../ui/verse-commentary-modal'

import { hasTouchEvents } from '../constants'
import { getValue, deleteValue } from '../utils'
import reader from '../lib/Reader'
import activities from '../lib/Activities'
import parallelReader from '../lib/ParallelReader'

import ChevronRight from 'lucide-static/icons/chevron-right.svg'
import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import ChevronUp from 'lucide-static/icons/chevron-up.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import BookOpenText from 'lucide-static/icons/book-open-text.svg'
import List from 'lucide-static/icons/list.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import Pen from 'lucide-static/icons/pen.svg'
import Copy from 'lucide-static/icons/clipboard-copy.svg'
import Obsidian from '../icons/obsidian.svg'
import ParallelReadingIcon from '../icons/parallel-reading.svg'
import ParallelReadingSyncIcon from '../icons/parallel-reading-sync.svg'

import * as ICONS from 'imba-phosphor-icons'

tag reader
	initialTouch = null
	inTouchZone = no
	inClosingTouchZone = no
	beforeUnloadHandler = null
	pageShowHandler = null
	pageHideHandler = null
	visibilityHandler = null
	splitDragging = no
	splitDragRAF = null

	get isSplitView
		return parallelReader.enabled or activities.commentaryCompareMode

	get isStackedSplit
		return window.innerWidth < 640

	get chapterViewportHeight
		if window.innerWidth < 1024
			return 'calc(100svh - 2.75rem)'
		return '100svh'

	get splitMainHeight
		return isSplitView ? chapterViewportHeight : 'auto'

	get splitMainMaxHeight
		return isSplitView ? chapterViewportHeight : 'none'

	def splitFlex first = yes
		unless isSplitView
			return '0 1 auto'
		const grow = first ? activities.splitRatio : (1 - activities.splitRatio)
		return "{grow} 1 0"

	def ensureSplitDragBindings
		unless #boundSplitMove
			#boundSplitMove = handleSplitDrag.bind(self)
		unless #boundSplitEnd
			#boundSplitEnd = endSplitDrag.bind(self)

	def startSplitDrag e
		return unless e
		ensureSplitDragBindings!
		splitDragging = yes
		document.documentElement.setAttribute('data-split-dragging', 'true')
		if e.target and e.target.setPointerCapture and e.pointerId != undefined
			try
				e.target.setPointerCapture(e.pointerId)
			catch err
				pass
		document.addEventListener('pointermove', #boundSplitMove)
		document.addEventListener('pointerup', #boundSplitEnd)
		document.addEventListener('pointercancel', #boundSplitEnd)
		document.addEventListener('mousemove', #boundSplitMove)
		document.addEventListener('mouseup', #boundSplitEnd)
		document.addEventListener('touchmove', #boundSplitMove, { passive: no })
		document.addEventListener('touchend', #boundSplitEnd)
		document.addEventListener('touchcancel', #boundSplitEnd)
		handleSplitDrag(e)

	def handleSplitDrag e
		if !splitDragging or !e or typeof e.type != 'string'
			return
		if e.cancelable
			e.preventDefault()
		e.stopPropagation()
		const container = document.getElementById('main')
		return unless container
		const touch = e.type.startsWith('touch') ? (e.touches and e.touches.length > 0 ? e.touches[0] : (e.changedTouches and e.changedTouches[0] ? e.changedTouches[0] : null)) : null
		const clientX = touch ? touch.clientX : e.clientX
		const clientY = touch ? touch.clientY : e.clientY
		if clientX == undefined or clientY == undefined
			return
		if splitDragRAF
			window.cancelAnimationFrame(splitDragRAF)
		splitDragRAF = window.requestAnimationFrame(do
			const rect = container.getBoundingClientRect()
			const ratio = isStackedSplit ? (clientY - rect.top) / rect.height : (clientX - rect.left) / rect.width
			splitDragRAF = null
			return unless isFinite(ratio)
			activities.setSplitRatio(ratio)
			imba.commit!
		)

	def endSplitDrag e
		document.documentElement.removeAttribute('data-split-dragging')
		if #boundSplitMove
			document.removeEventListener('pointermove', #boundSplitMove)
			document.removeEventListener('mousemove', #boundSplitMove)
			document.removeEventListener('touchmove', #boundSplitMove)
		if #boundSplitEnd
			document.removeEventListener('pointerup', #boundSplitEnd)
			document.removeEventListener('pointercancel', #boundSplitEnd)
			document.removeEventListener('mouseup', #boundSplitEnd)
			document.removeEventListener('touchend', #boundSplitEnd)
			document.removeEventListener('touchcancel', #boundSplitEnd)
		if splitDragRAF
			window.cancelAnimationFrame(splitDragRAF)
			splitDragRAF = null
		if splitDragging
			activities.saveSplitRatio!
		splitDragging = no
		imba.commit!

	def resetSplitRatio
		activities.setSplitRatio(0.5)
		activities.saveSplitRatio!
		imba.commit!

	def onPopState event
		if event.target.hash
			return
		activities.cleanUp { onPopState: yes }

	def onSelectionChange
		if window.getSelection().toString().length > 0
			self.dictionary.showTooltip!
		setTimeout(&, 150) do
			let selection = document.getSelection()
			if selection.isCollapsed and self.dictionary.tooltip
				self.dictionary.tooltip = null
				imba.commit!

	handleCopySelectDragRAF = null
	lastDragVersePK = 0
	
	def handleCopySelectDrag e\MouseEvent|TouchEvent
		if !e or typeof e.type != 'string'
			return
		if !activities.copySelectDragging or !activities.copySelectReader
			return
		
		e.preventDefault()
		e.stopPropagation()
		
		document.documentElement.setAttribute('data-copy-select-dragging', 'true')
		
		# Use window.requestAnimationFrame for smooth, real-time updates
		if handleCopySelectDragRAF
			window.cancelAnimationFrame(handleCopySelectDragRAF)
		
		# Capture coordinates before RAF to avoid stale event refs
		let touch = e.type.startsWith('touch') ? (e.touches and e.touches.length > 0 ? e.touches[0] : (e.changedTouches and e.changedTouches[0] ? e.changedTouches[0] : null)) : null
		let clientX = touch ? touch.clientX : e.clientX
		let clientY = touch ? touch.clientY : e.clientY
		handleCopySelectDragRAF = window.requestAnimationFrame(do
			let element = document.elementFromPoint(clientX, clientY)
			if !element
				return
			
			# Find the verse element by traversing up the DOM - look for elements with id that match verse pattern
			let verseElement = element
			let maxDepth = 15
			let depth = 0
			while verseElement and depth < maxDepth
				if verseElement.id and (verseElement.id.match(/^\d+$/) or verseElement.id.match(/^p\d+$/))
					break
				verseElement = verseElement.parentElement
				depth++
			
			if !verseElement or !verseElement.id
				return
			
			let verseId = verseElement.id.replace(/^p/, '')
			let verse = activities.copySelectReader.verses.find(do |v| return String(v.verse) == verseId)
			if !verse or verse.pk == lastDragVersePK
				return
			
			lastDragVersePK = verse.pk
			let readerType = activities.copySelectReader.me or ''
			
			if activities.copySelectDragHandle == 'top'
				if readerType == 'main'
					activities.copySelectStartPKMain = verse.pk
				else
					activities.copySelectStartPKParallel = verse.pk
				activities.copySelectStartPK = verse.pk
			elif activities.copySelectDragHandle == 'bottom'
				if readerType == 'main'
					activities.copySelectEndPKMain = verse.pk
				else
					activities.copySelectEndPKParallel = verse.pk
				activities.copySelectEndPK = verse.pk
			
			activities.copySelectReader.updateCopySelectRange!
			imba.commit!
			handleCopySelectDragRAF = null
		)
	
	def handleCopySelectDragEnd
		document.documentElement.removeAttribute('data-copy-select-dragging')
		if handleCopySelectDragRAF
			window.cancelAnimationFrame(handleCopySelectDragRAF)
			handleCopySelectDragRAF = null
		lastDragVersePK = 0
		activities.copySelectDragging = no
		activities.copySelectDragHandle = ''
		activities.copySelectReader = null
		imba.commit!

	def handleClickOutside e\MouseEvent|TouchEvent
		# Deselect verses when clicking outside the article (text content area)
		if activities.selectedVersesPKs.length > 0 or activities.copySelectedVersesPKs.length > 0
			if !e.target
				return
			
			const clickTarget = e.target
			
			# Find the article element that contains the verses (inside main-reader)
			const mainReader = document.getElementById('main-reader')
			if !mainReader
				return
			
			const article = mainReader.querySelector('article')
			if !article
				return
			
			# If verse-actions, commentary modal, or compare mode is open, don't clear selection on any click
			if activities.activeVerseAction == 'options' or activities.activeVerseAction == 'commentary' or activities.activeVerseAction == 'suppressed'
				return
			
			# SECOND: Check if we're clicking inside verse-actions or any UI element that should preserve selection
			# Check multiple ways to catch all cases
			const isVerseActions = clickTarget.closest('.verse-actions')
			const isColorOption = clickTarget.closest('.color-option') or clickTarget.classList.contains('color-option')
			const isButton = clickTarget.tagName == 'BUTTON' or clickTarget.closest('button')
			const isUIElement = clickTarget.closest('.modal, .drawer, .settings-drawer, .books-drawer, .verse-actions, .commentary-modal, .commentary-overlay, .commentary-pane, .menu-popup, button, a, input, select, textarea, .verse-selection-box, .verse-selection-insert-btn, .verse-selection-close-btn, header, nav, .drawer-handle, .parallel-divider')
			
			# If clicking on color options or inside verse-actions, preserve selection
			if isVerseActions or isColorOption or (isButton and clickTarget.closest('section.verse-actions'))
				return
			
			# For other UI elements, also preserve selection
			if isUIElement
				return
			
			# Check if click is inside the article (text content area)
			const isInsideArticle = article.contains(clickTarget)
			
			# Deselect if clicking outside the article (padding/margins) and not on UI elements
			if !isInsideArticle
				activities.selectedVerses = []
				activities.selectedVersesPKs = []
				activities.copySelectedVersesPKs = []
				activities.copySelectStartPK = 0
				activities.copySelectEndPK = 0
				activities.selectedParallel = undefined
				activities.activeVerseAction = undefined
				# Clear browser selections too
				if window.getSelection
					window.getSelection().removeAllRanges()
				imba.commit!

	def mount
		# Reload/debug instrumentation (no override of window.location.reload)
		beforeUnloadHandler = do(e)
			console.log('[RELOAD DEBUG] beforeunload', {
				url: window.location.href,
				visibility: document.visibilityState
			})

		pageShowHandler = do(e)
			try
				let nav = null
				if window.performance and typeof window.performance.getEntriesByType == 'function'
					const entries = window.performance.getEntriesByType('navigation')
					if entries and entries.length
						nav = entries[0]
				console.log('[RELOAD DEBUG] pageshow', {
					persisted: e.persisted,
					type: nav and nav.type,
					url: window.location.href
				})
			catch err
				console.log('[RELOAD DEBUG] pageshow error', { message: err and err.message })

		pageHideHandler = do(e)
			console.log('[RELOAD DEBUG] pagehide', {
				persisted: e.persisted,
				url: window.location.href
			})

		visibilityHandler = do
			console.log('[RELOAD DEBUG] visibilitychange', {
				visibility: document.visibilityState,
				url: window.location.href
			})

		window.addEventListener('beforeunload', beforeUnloadHandler)
		window.addEventListener('pageshow', pageShowHandler)
		window.addEventListener('pagehide', pageHideHandler)
		document.addEventListener('visibilitychange', visibilityHandler)

		document.addEventListener('selectionchange', onSelectionChange.bind(self))
		window.addEventListener('popstate', onPopState.bind(self))
		window.onblur = hidePanels.bind(self)
		document.body.onmouseleave = hidePanels.bind(self)
		document.onmouseleave = hidePanels.bind(self)
		window.onmouseout = hidePanels.bind(self)
		window.onresize = imba.commit
		document.addEventListener('mousemove', handleCopySelectDrag.bind(self), true)
		document.addEventListener('mouseup', handleCopySelectDragEnd.bind(self), true)
		document.addEventListener('touchmove', handleCopySelectDrag.bind(self), true)
		document.addEventListener('touchend', handleCopySelectDragEnd.bind(self), true)
		document.addEventListener('click', handleClickOutside.bind(self), true)

		window.strongDefinition = do(topic)
			self.dictionary.query = topic
			self.dictionary.loadDefinitions!

		# TODO clean up this at some point
		if getValue('enable_dynamic_contrast')
			setTimeout(&, 2000) do
				// Tell the user we don't support this feature anymore and offer them to create a custom theme instead which has better control
				const message = "Dynamic contrast is not supported anymore. You can create a custom theme instead, that has better control over the contrast."
				const confirm = await window.confirm(message)
				if confirm
					activities.openCustomTheme!
				deleteValue('enable_dynamic_contrast')


	def unmount
		if beforeUnloadHandler
			window.removeEventListener('beforeunload', beforeUnloadHandler)
			beforeUnloadHandler = null
		if pageShowHandler
			window.removeEventListener('pageshow', pageShowHandler)
			pageShowHandler = null
		if pageHideHandler
			window.removeEventListener('pagehide', pageHideHandler)
			pageHideHandler = null
		if visibilityHandler
			document.removeEventListener('visibilitychange', visibilityHandler)
			visibilityHandler = null
		document.removeEventListener('selectionchange', onSelectionChange.bind(self))
		window.removeEventListener('popstate', onPopState.bind(self))
		document.removeEventListener('mousemove', handleCopySelectDrag.bind(self), true)
		document.removeEventListener('mouseup', handleCopySelectDragEnd.bind(self), true)
		document.removeEventListener('touchmove', handleCopySelectDrag.bind(self), true)
		document.removeEventListener('touchend', handleCopySelectDragEnd.bind(self), true)
		document.removeEventListener('click', handleClickOutside.bind(self), true)

	@action def routed params
		const link_segments = window.location.pathname.split('/').filter(Boolean)
		unless params.translation and params.book and params.chapter
			return
		const book = parseInt(params.book, 10)
		const chapter = parseInt(params.chapter, 10)
		if Number.isNaN(book) or Number.isNaN(chapter)
			return
		# Ignore stale routed events right after a tab switch or modal navigation
		if activities.routeLockUntil and Date.now() < activities.routeLockUntil and activities.routeLockTab
			const lock = activities.routeLockTab
			if params.translation != lock.translation or book != lock.book or chapter != lock.chapter
				console.log('[TAB DEBUG] reader routed skipped (route lock)', {
					params,
					lock
				})
				return
			# Reader was already updated programmatically — keep the lock until it expires
			return
		# Guard against stale router params (URL is source of truth)
		const offset = link_segments[0] == 'international' ? 1 : 0
		const actualTranslation = link_segments[offset]
		const actualBook = parseInt(link_segments[offset + 1], 10)
		const actualChapter = parseInt(link_segments[offset + 2], 10)
		if actualTranslation and !Number.isNaN(actualBook) and !Number.isNaN(actualChapter)
			if params.translation != actualTranslation or book != actualBook or chapter != actualChapter
				console.log('[TAB DEBUG] reader routed skipped (stale params)', {
					params,
					actual: { translation: actualTranslation, book: actualBook, chapter: actualChapter }
				})
				return
		# Skip if already in sync (prevents tab overwrite on switches)
		if reader and reader.translation == params.translation and reader.book == book and reader.chapter == chapter
			return
		console.log('[TAB DEBUG] reader routed', {
			params,
			book,
			chapter,
			current: { translation: reader.translation, book: reader.book, chapter: reader.chapter }
		})
		if 'international' in window.location.pathname
			if link_segments.length == 5
				reader.verse = link_segments[-1]
		else
			reader.translation = params.translation
			if link_segments.length == 4
				reader.verse = link_segments[-1]
		reader.book = book
		reader.chapter = chapter


	def hidePanels event\MouseEvent
		if !settings.fixdrawers && (event.clientY < 0 || event.clientX < 0 || (event.clientX > window.innerWidth || event.clientY > window.innerHeight))
			inTouchZone = no
			inClosingTouchZone = no
			activities.booksDrawerOffset = -300
			activities.settingsDrawerOffset = -300
			imba.commit!


	def isStylusTouchEvent e
		unless e and e.changedTouches and e.changedTouches.length
			return no
		const touch = e.changedTouches[0]
		if touch and (touch.touchType == 'stylus' or touch.touchType == 'pen')
			return yes
		return no

	def slidestart touch
		if activities.penBlocksSwipe or isStylusTouchEvent(touch)
			return
		unless touch.changedTouches.length
			return
		initialTouch = touch.changedTouches[0]
		if initialTouch.clientX < 16 or initialTouch.clientX > window.innerWidth - 16
			inTouchZone = yes

	def slideend touch
		if activities.penBlocksSwipe or isStylusTouchEvent(touch)
			initialTouch = null
			inTouchZone = no
			return
		unless initialTouch
			return
		touch = touch.changedTouches[0]

		touch.dy = initialTouch.clientY - touch.clientY
		touch.dx = initialTouch.clientX - touch.clientX

		if activities.booksDrawerOffset > -300
			if inTouchZone
				touch.dx > 64 ? activities.booksDrawerOffset = 0 : activities.booksDrawerOffset = -300
			else
				touch.dx < -64 ? activities.booksDrawerOffset = -300 : activities.booksDrawerOffset = 0
		elif activities.settingsDrawerOffset > -300
			if inTouchZone
				touch.dx > 64 ? activities.settingsDrawerOffset = 0 : activities.settingsDrawerOffset = -300
			else
				touch.dx < -64 ? activities.settingsDrawerOffset = -300 : activities.settingsDrawerOffset = 0
		elif document.getSelection().isCollapsed && Math.abs(touch.dy / touch.dx) < 0.3 && !activities.selectedVerses.length
			if window.innerWidth > 600
				if touch.dx < -32
					parallelReader.enabled && touch.clientX > window.innerWidth / 2 ? parallelReader.prevChapter! : reader.prevChapter!
				elif touch.dx > 32
					parallelReader.enabled && touch.clientX > window.innerWidth / 2 ? parallelReader.nextChapter! : reader.nextChapter!
			else
				if touch.dx < -32
					parallelReader.enabled && touch.clientY > window.innerHeight / 2 ? parallelReader.prevChapter! : reader.prevChapter!
				elif touch.dx > 32
					parallelReader.enabled && touch.clientY > window.innerHeight / 2 ? parallelReader.nextChapter! : reader.nextChapter!

		initialTouch = null
		inTouchZone = no


	def closingdrawer e
		if activities.penBlocksSwipe or isStylusTouchEvent(e)
			return
		unless e.changedTouches.length
			return
		e.dx = e.changedTouches[0].clientX - initialTouch.clientX

		if activities.booksDrawerOffset > -300 && e.dx > 0
			activities.booksDrawerOffset = - e.dx
		if activities.settingsDrawerOffset > -300 && e.dx > 0
			activities.settingsDrawerOffset = - e.dx
		inClosingTouchZone = yes

	def openingdrawer e
		if activities.penBlocksSwipe or isStylusTouchEvent(e)
			return
		unless e.changedTouches.length
			return
		if inTouchZone
			e.dx = e.changedTouches[0].clientX - initialTouch.clientX

			if activities.booksDrawerOffset < 0 && e.dx < 0
				activities.booksDrawerOffset = - e.dx - 300
			if activities.settingsDrawerOffset < 0 && e.dx < 0
				activities.settingsDrawerOffset = - e.dx - 300

	def closedrawersend touch
		unless touch.changedTouches.length
			return
		touch.dx = touch.changedTouches[0].clientX - initialTouch.clientX

		if activities.booksDrawerOffset > -300
			touch.dx > 64 ? activities.booksDrawerOffset = -300 : activities.booksDrawerOffset = 0
		elif activities.settingsDrawerOffset > -300
			touch.dx > 64 ? activities.settingsDrawerOffset = -300 : activities.settingsDrawerOffset = 0
		inClosingTouchZone = no

	def openBooksDrawer
		unless settings.fixdrawers or hasTouchEvents
			activities.booksDrawerOffset = 0
	
	def closeBooksDrawer
		unless settings.fixdrawers or hasTouchEvents
			activities.booksDrawerOffset = -300

	def openSettingsDrawer
		unless settings.fixdrawers or hasTouchEvents
			activities.settingsDrawerOffset = 0
	
	def closeSettingsDrawer
		unless settings.fixdrawers or hasTouchEvents
			activities.settingsDrawerOffset = -300

	def interpolate value, max
		# result should be between 0 and max
		Math.min(Math.max(value, 0), max)
		

	def boxShadow grade\number
		const abs = grade + 300
		return "0 0 0 {interpolate(abs, 1)}px var(--acc-bgc), 0 {interpolate(abs,1)}px {interpolate(abs, 6)}px var(--acc-bgc), 0 {interpolate(abs,3)}px {interpolate(abs, 36)}px var(--acc-bgc), 0 9px {interpolate(abs, 128)}px -{interpolate(abs, 64)}px var(--acc-bgc)"

	get drawerTransiton
		(inClosingTouchZone || inTouchZone) ? '0' : '450ms'

	def paneWidth mainReader = yes
		const usable = window.innerWidth - pageSearch.drawerOffset
		if isStackedSplit
			return usable
		return usable * (mainReader ? activities.splitRatio : (1 - activities.splitRatio))

	def readerPadding mainReader = yes
		if activities.commentaryCompareMode
			# In compare mode the reader only owns part of the viewport,
			# so the centering padding has to be computed against that share.
			const available = paneWidth(mainReader)
			const desired = Math.min(theme.maxWidth * theme.fontSize, Math.max(0, available - 32))
			const padding = Math.max(12, (available - desired) / 2)
			return "{padding}px"
		if parallelReader.enabled
			# the padding is 0 on the side of the parallel reader
			# the parallel should not have padding in between them. Take into account text direction
			const textDirection = translationTextDirection(mainReader ? reader.translation : parallelReader.translation)
			const oneSidePadding = Math.max(0, paneWidth(mainReader) - theme.maxWidth * theme.fontSize)
			if (textDirection == 'rtl' && mainReader) or (textDirection == 'ltr' && !mainReader)
				return "0 {oneSidePadding}px"
			return "{oneSidePadding}px 0"
		# the body should be centered theme.maxWidth
		return "{(window.innerWidth - theme.maxWidth * theme.fontSize) / 2 - pageSearch.drawerOffset}px"

	get bibleIconTransform
		if (settings.fixdrawers && window.innerWidth >= 1024)
			return -300 - activities.booksDrawerOffset
		return 0

	def cleanUpSelection
		let selectedText = window.getSelection().toString()
		if selectedText.length > 0
			pageSearch.query = selectedText
			search.query = selectedText
		activities.cleanUp { onPopState: yes }

	@action def toggleParallelReading
		if !parallelReader.enabled
			settings.parallel_sync = no
			parallelReader.enable = yes
		elif !settings.parallel_sync
			settings.parallel_sync = yes
			reader.updateParallelReader(reader.book, reader.chapter)
			window.requestAnimationFrame(do
				const mainChapter = document.getElementById('main-reader')
				if mainChapter and mainChapter.calculateTopVerse
					mainChapter.calculateTopVerse({target: mainChapter})
			)
		else
			settings.parallel_sync = no
			parallelReader.enable = no
		imba.commit!

	def toggleCopySelectMode
		let wasOff = !activities.copySelectMode
		activities.copySelectMode = !activities.copySelectMode
		
		if !activities.copySelectMode
			# Turning OFF - clear selection for both readers
			activities.copySelectedVersesPKs = []
			activities.copySelectStartPK = 0
			activities.copySelectEndPK = 0
			activities.copySelectStartPKMain = 0
			activities.copySelectEndPKMain = 0
			activities.copySelectStartPKParallel = 0
			activities.copySelectEndPKParallel = 0
			activities.copySelectModeReader = null
		elif wasOff and activities.selectedVersesPKs.length > 0
			# Turning ON and there are selected verses - activate purple box
			let selectedPKs = activities.selectedVersesPKs
			if selectedPKs.length > 0
				# Determine which reader has these verses and update the selection box
				let targetReader = null
				let readerType = ''
				
				# First check selectedParallel
				if activities.selectedParallel == 'main'
					targetReader = reader
					readerType = 'main'
				elif activities.selectedParallel == parallelReader
					targetReader = parallelReader
					readerType = 'parallel'
				else
					# Try to determine which reader has these verses by checking PKs
					let hasMainVerses = reader.verses.some(do |v| return selectedPKs.includes(v.pk))
					let hasParallelVerses = parallelReader.verses.some(do |v| return selectedPKs.includes(v.pk))
					
					if hasMainVerses and !hasParallelVerses
						targetReader = reader
						readerType = 'main'
					elif hasParallelVerses and !hasMainVerses
						targetReader = parallelReader
						readerType = 'parallel'
					elif hasMainVerses and hasParallelVerses
						# Both have verses - prefer the one with more matches
						let mainCount = reader.verses.filter(do |v| return selectedPKs.includes(v.pk)).length
						let parallelCount = parallelReader.verses.filter(do |v| return selectedPKs.includes(v.pk)).length
						if parallelCount >= mainCount
							targetReader = parallelReader
							readerType = 'parallel'
						else
							targetReader = reader
							readerType = 'main'
				
				# Set the active reader and update the selection box
				if targetReader
					activities.copySelectModeReader = targetReader
					# Set per-reader PKs
					if readerType == 'main'
						activities.copySelectStartPKMain = selectedPKs[0]
						activities.copySelectEndPKMain = selectedPKs[selectedPKs.length - 1]
					else
						activities.copySelectStartPKParallel = selectedPKs[0]
						activities.copySelectEndPKParallel = selectedPKs[selectedPKs.length - 1]
					# Also set global PKs for backward compatibility
					activities.copySelectStartPK = selectedPKs[0]
					activities.copySelectEndPK = selectedPKs[selectedPKs.length - 1]
					targetReader.updateCopySelectRange!
		
		imba.commit!

	def openProfile
		if user.username
			router.go('/profile')
		else
			window.location.href = '/accounts/login'

	def render
		<self[d:flex] @touchstart=slidestart @touchmove=openingdrawer @touchend=slideend @touchcancel=slideend>
			<main id="main"
				.parallel_text=parallelReader.enabled .hide-comments=!settings.verse_commentary .parallels=(parallelReader.enabled or activities.commentaryCompareMode) .commentary-compare=activities.commentaryCompareMode
				[pos:{(parallelReader.enabled or activities.commentaryCompareMode) ? 'relative' : 'static'} ff:{theme.fontFamily} fs:{theme.fontSize}px lh:{theme.lineHeight} fw:{theme.fontWeight} ta:{theme.align} fl:1]
				[height:{splitMainHeight} max-height:{splitMainMaxHeight} min-height:0 overflow:{isSplitView ? 'hidden' : 'visible'}]
				[data-bm={((reader.bookmarks and reader.bookmarks.length) or 0) + '-' + (parallelReader.enabled ? ((parallelReader.bookmarks and parallelReader.bookmarks.length) or 0) : 0)}]
				>
				<chapter id="main-reader" me=reader [padding-inline:{readerPadding!} box-sizing:border-box flex:{splitFlex(yes)} height:auto max-height:{isSplitView ? 'none' : chapterViewportHeight} min-width:0 min-height:0] />
				if isSplitView
					<div.parallel-divider>
						<span.parallel-divider-line aria-hidden=yes>
						<div.parallel-divider-handle
							role="separator"
							title=(t.parallel or "Resize")
							@pointerdown.prevent.stop=startSplitDrag
							@mousedown.prevent.stop=startSplitDrag
							@touchstart.prevent.stop=startSplitDrag
							@dblclick.prevent.stop=resetSplitRatio>
							<span.parallel-divider-grip aria-hidden=yes>
					if activities.commentaryCompareMode
						<verse-commentary-modal />
					else
						<chapter id="parallel-reader" me=parallelReader [padding-inline:{readerPadding(no)} box-sizing:border-box flex:{splitFlex(no)} height:auto max-height:none min-width:0 min-height:0] versePrefix="p" />

			<global
				@hotkey('mod+shift+f|mod+k').force.prevent.stop.cleanUpSelection=activities.showSearch
				@hotkey('s|f|і|а').prevent.stop.cleanUpSelection=activities.showSearch

				@hotkey('mod+f').prevent.stop.cleanUpSelection=pageSearch.run
				@hotkey('alt+r').prevent.stop=reader.randomVerse
				@hotkey('mod+y').prevent.stop=(settings.fixdrawers = !settings.fixdrawers)

				@hotkey('mod+d|mod+в').prevent.stop=dictionary.showDictionary
				@hotkey('alt+s|alt+і').prevent.stop=dictionary.showStrongNumberDefinition
				@hotkey('escape').force.prevent.stop=activities.cleanUp
				@hotkey('mod+alt+h').prevent.stop=(settings.menuicons = !settings.menuicons)

				@hotkey('mod+right').prevent.stop=reader.nextChapter
				@hotkey('mod+left').prevent.stop=reader.prevChapter
				@hotkey('mod+n').prevent.stop=reader.nextBook
				@hotkey('mod+p').prevent.stop=reader.prevBook
				@hotkey('alt+n').prevent.stop=reader.nextBook
				@hotkey('alt+p').prevent.stop=reader.prevBook
				@hotkey('alt+shift+right').prevent.stop=parallelReader.nextChapter
				@hotkey('alt+shift+left').prevent.stop=parallelReader.prevChapter

				@hotkey('mod+[').prevent.stop=theme.decreaseFontSize
				@hotkey('mod+]').prevent.stop=theme.increaseFontSize

				@hotkey('mod+,').prevent.stop=activities.showHelp
				@hotkey('alt+z').prevent.stop=openProfile
			>

				<settings-drawer
					[r:{activities.settingsDrawerOffset}px bxs:{boxShadow(activities.settingsDrawerOffset)} transition-duration:{drawerTransiton}]
					@touchstart=slidestart @touchend=closedrawersend @touchcancel=closedrawersend @touchmove=closingdrawer @pointerleave=closeSettingsDrawer>


				if activities.activeModal
					<modal />

				if activities.activeVerseAction == 'options' and activities.selectedVersesPKs.length > 0
					<verse-actions />
				if activities.activeVerseAction == 'commentary' and activities.selectedVersesPKs.length > 0 and !activities.commentaryCompareMode
					<verse-commentary-modal />

				if (reader.loading || parallelReader.loading || dictionary.loading || search.loading || compare.loading) and !activities.isSwitchingTab
					<loading>

				if pageSearch.on
					<section ease>
						css
							pos:fixed b:0 y@off:100% l:0 r:0 zi:1100
							d:flex ai:center
							p:.5rem
							bdt:1px solid $acc-bgc
							bgc:$bgc

							input
								inline-size: auto
								min-width: 4rem;
								padding: .25rem
								font-size: 1.25rem
								background: $acc-bgc focus:$acc-bgc-hover
								border: 1px solid $acc-bgc
								color: inherit
								-webkit-border-radius: .25rem
								border-radius: .25rem
								opacity: 0.7 @hover:1 @focus:1
								border-top-right-radius:0
								border-bottom-right-radius:0

							button
								opacity: 0.7 @hover:1
								d:hcc
								svg
									height: 2rem
									width: 2.25rem
									min-width: 2rem

						<[d:flex mr:1rem rd:.25rem] [ol:.25rem solid rose8/50]=(!pageSearch.matches.length && pageSearch.query.length)>
							<input#pageSearch bind=pageSearch.query
								@input=pageSearch.run @keydown.enter=pageSearch.pageSearchKeydownManager
								[direction:{textDirection(pageSearch.query)}]
								placeholder=t.find_in_chapter>
							<button @click=pageSearch.prevOccurrence title=t.prev
								[rd:0 bgc:$acc-bgc @hover:$acc-bgc-hover]>
								<svg src=ChevronUp>
							<button @click=pageSearch.nextOccurrence title=t.next
								[border-top-right-radius:.25rem border-bottom-right-radius:.25rem bgc:$acc-bgc @hover:$acc-bgc-hover]>
								<svg src=ChevronDown>

						if pageSearch.matches.length
							<p> pageSearch.current_occurrence + 1, ' / ', pageSearch.matches.length
						elif pageSearch.query.length != 0 && window.innerWidth > 640
							<p> t.phrase_not_found

						<button[c@hover:red4 ml:auto] @click=activities.cleanUp title=t.close>
							<svg src=ICONS.X aria-hidden=yes>

				if dictionary.tooltip
					<div
						[pos:fixed l:{dictionary.tooltip.left}px r:{dictionary.tooltip.right}px t:{dictionary.tooltip.top}px zi:1 scale@off:0.75 o@off:0] ease>
						css
							bg:$acc-bgc rd:4px
							origin:top center
							bd:1px solid $acc-bgc-hover
							
							button
								bgc:transparent @hover:$acc-bgc-hover
								fs:inherit font:inherit c:inherit
								cursor:pointer p: 8px

						<button @click=dictionary.loadDefinitions(dictionary.tooltip.selected)> dictionary.tooltip.selected
						if dictionary.tooltip.strong
							'|'
							<button @click=dictionary.loadDefinitions(dictionary.tooltip.strong)> dictionary.tooltip.strong

				if settings.menuicons and not (activities.activeModal && window.innerWidth < 640)
					<section [o@off:0 b@lt-lg:0px] ease>
						css
							pos:fixed
							zi:2
							d:flex
							fld:column
							jc:center
							ai:center
							g:.5rem
							w:auto
							h:auto
							p:.5rem
							bgc:$bgc
							bd:1px solid $acc-bgc
							rd:.75rem
							right:.75rem
							top:50%
							transform:translateY(-50%)
							cursor:pointer
							left@lt-lg:0px
							right@lt-lg:0px
							bottom@lt-lg:0px
							top@lt-lg:auto
							transform@lt-lg:none
							w@lt-lg:100%
							fld@lt-lg:row
							jc@lt-lg:space-between
							g@lt-lg:0
							p@lt-lg:0
							rd@lt-lg:0
							bd@lt-lg:none
							bdt@lt-lg:1px solid $acc-bgc

							button
								w:2.75rem
								h:2.75rem
								min-width:2.75rem
								p:0
								bgc:transparent
								c:$acc @hover:$acc-hover
								d:hcc
								flex@lt-lg:1
								w@lt-lg:calc(100% / 8)

							button.parallel-active
								c: var(--freehand-color, GoldenRod)
								svg
									c: var(--freehand-color, GoldenRod)
							
							svg
								o@lt-lg:0.75 @hover:1
								size:1.5rem @lt-lg:1.25rem

						<button @click=reader.prevChapter title=t.prev>
							<svg src=ChevronLeft aria-hidden=yes>
						<button[transform: translateX({bibleIconTransform}px)] @click=activities.toggleBooksMenu title=t.change_book>
							<svg src=BookOpenText aria-hidden=yes>
						<button .copy-select-active=(activities.copySelectMode) @click=toggleCopySelectMode title="Obsidian">
							<svg src=Obsidian aria-hidden=yes>
						<button .freehand-highlight-active=(activities.freehandHighlightMode) @click=(activities.toggleFreehandHighlightMode!) title="Freehand Highlight">
							<svg src=Highlighter aria-hidden=yes>
						<button .pen-tool-active=(activities.penToolMode) @click=(activities.togglePenToolMode!) title="Pen Tool">
							<svg src=Pen aria-hidden=yes>
						<button .parallel-active=(parallelReader.enabled) .parallel-sync-active=(parallelReader.enabled and settings.parallel_sync) @click=toggleParallelReading title=(parallelReader.enabled and settings.parallel_sync ? t.parallel_sync : t.parallel)>
							<svg src=(parallelReader.enabled and settings.parallel_sync ? ParallelReadingSyncIcon : ParallelReadingIcon) aria-hidden=yes>
						<button .bookmarks-active=(activities.activeModal == 'bookmarks') @click=activities.showBookmarksModal title="Highlights and Bookmarks">
							<svg src=List aria-hidden=yes>
						<button @click=reader.nextChapter title=t.next>
							<svg src=ChevronRight aria-hidden=yes>



	css
		min-h: 100vh
		min-h: -webkit-fill-available

		#main
			min-width: 0
			overflow-x: hidden

		#main.commentary-compare
			flex: 1
			min-h: 0
			overflow: hidden
			h: 100vh
			h@lt-lg: calc(100vh - 2.75rem)

		.copy-select-active
			c: #a855f7
			svg
				c: #a855f7
		
		.freehand-highlight-active
			c: var(--freehand-color, GoldenRod)
			svg
				c: var(--freehand-color, GoldenRod)
		
		.pen-tool-active
			c: var(--freehand-color, GoldenRod)
			svg
				c: var(--freehand-color, GoldenRod)

		.parallel-active
			c: var(--freehand-color, GoldenRod)
			svg
				c: var(--freehand-color, GoldenRod)

		.bookmarks-active
			c: var(--freehand-color, GoldenRod)
			svg
				c: var(--freehand-color, GoldenRod)
		
		nav, aside
			h: 100vh
			position: fixed
			top: 0
			bottom: 0
			width: 300px
			z-index: 1000
			background-color: var(--bgc)

		nav
			border-left: 1px solid var(--acc-bgc)
			transition-property: right
			will-change: right
			padding-inline: 0
			padding-block: 0.5rem 2rem


		aside
			border-left: 1px solid var(--acc-bgc)
			transition-property: right
			will-change: right
			padding-inline: 0.75rem
			padding-block: 1rem 2rem
			overflow-y: auto
			-webkit-overflow-scrolling: touch

		.parallels
			d:flex
			fld@lt-sm:column
			g:0
			min-width: 0
			min-h: 0
			align-self: stretch

			@lt-sm
				flex: 1
				min-h: 0
				w: 100%

			&.commentary-compare
				flex: 1
				h: 100%
				min-h: 0
				max-h: 100%
				overflow: hidden

			.parallel-divider
				flex: 0 0 16px
				align-self: stretch
				flex-shrink: 0
				bgc: transparent
				border: none
				p: 0
				m: 0
				pos: relative
				overflow: visible
				zi: 25

				@lt-sm
					align-self: auto
					w: 100%
					h: 16px
					flex: 0 0 16px

			.parallel-divider-line
				pos: absolute
				left: 50%
				top: 0
				bottom: 0
				w: 2px
				transform: translateX(-50%)
				bgc: $acc-bgc
				pointer-events: none

				@lt-sm
					left: 0
					right: 0
					top: 50%
					bottom: auto
					w: auto
					h: 2px
					transform: translateY(-50%)

			.parallel-divider-handle
				pos: absolute
				left: 50%
				top: 50%
				transform: translate(-50%, -50%)
				d: hcc
				w: 16px
				h: 84px
				p: 0
				m: 0
				bgc: $bgc
				border: none
				cursor: col-resize
				touch-action: none
				user-select: none
				zi: 26

				@lt-sm
					w: 84px
					h: 16px
					cursor: row-resize

			.parallel-divider-grip
				d: block
				w: 6px
				h: 64px
				rd: 999px
				bgc: $acc
				opacity: 0.65 @hover:1
				pointer-events: none
				transition: opacity 150ms ease

				@lt-sm
					w: 64px
					h: 6px

			section
				min-width: 0
				min-h: 0
				-webkit-overflow-scrolling: touch

				@lt-sm
					w: 100%

		.drawer-handle
			w:2vw w:min(1.5rem, max(1rem, 2vw))
			h:100vh
			bgc:gray4/25
			o:0 @hover:1
			d:hcc cursor:pointer zi:2 c:$acc 

global css
	html[data-split-dragging="true"]
		user-select: none

	html[data-split-dragging="true"] .parallel-divider-grip
		opacity: 1
