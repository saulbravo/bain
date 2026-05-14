import Color from "colorjs.io"

import readingHistory from './ReadingHistory'
import { hasTouchEvents } from '../constants'

import { getBookName, getValue, setValue } from '../utils'

import pageSearch from './PageSearch'
import parallelReader from './ParallelReader'
import reader from './Reader'
import dictionary from './Dictionary'
import search from './Search'
import notifications from './Notifications'
import user from './User'
import theme from './Theme'
import customTheme from './CustomTheme'
import settings from './Settings'

import type { CopyObject, Verse } from './types'

class Activities 
	debugTabs = yes
	highlightColors = [
		'#F4A3A3'
		'#F7C59F'
		'#F9E2A0'
		'#B7E4C7'
		'#A7C7E7'
		'#CDB4DB'
	]
	penColors = [
		'#000000'
		'#DC2626'
		'#F4A3A3'
		'#F7C59F'
		'#F9E2A0'
		'#B7E4C7'
		'#A7C7E7'
		'#CDB4DB'
	]
	@observable bookBookmarks = Array.isArray(getValue('book-bookmarks')) ? getValue('book-bookmarks') : []

	def bookBookmarkKey translation\string, book\number, chapter\number
		return "{translation}:{book}:{chapter}"

	def legacyBookBookmarkKey translation\string, book\number
		return "{translation}:{book}"

	def isBookBookmarked translation\string, book\number, chapter\number
		const key = bookBookmarkKey(translation, book, chapter)
		const legacyKey = legacyBookBookmarkKey(translation, book)
		return bookBookmarks.some(do |entry|
			if !entry
				return no
			if entry.key == key
				return yes
			# Backward compatibility with old saved keys that didn't include chapter.
			if entry.key == legacyKey and (entry.chapter == undefined or entry.chapter == null)
				return yes
			return no
		)

	def toggleBookBookmark translation\string, book\number, chapter\number
		const key = bookBookmarkKey(translation, book, chapter)
		const legacyKey = legacyBookBookmarkKey(translation, book)
		const index = bookBookmarks.findIndex(do |entry|
			if !entry
				return no
			if entry.key == key
				return yes
			# Remove old book-level bookmark when upgrading to chapter-aware bookmarks.
			if entry.key == legacyKey and (entry.chapter == undefined or entry.chapter == null)
				return yes
			return no
		)
		if index >= 0
			bookBookmarks.splice(index, 1)
		else
			bookBookmarks.push({
				key: key
				translation: translation
				book: book
				chapter: chapter
				name: getBookName(translation, book)
				date: Date.now()
			})
		setValue('book-bookmarks', bookBookmarks)

	def tabSummary tab
		return tab ? {
			name: tab.name
			translation: tab.translation
			book: tab.book
			chapter: tab.chapter
		} : null

	def readerSummary
		return {
			translation: reader.translation
			book: reader.book
			chapter: reader.chapter
		}

	def logTabDebug message\string, data\object = {}
		return unless debugTabs
		try
			console.log("[TAB DEBUG] {message} {JSON.stringify(data)}")
		catch err
			console.log("[TAB DEBUG] {message}", data)
	show_accents = no
	show_themes = no
	show_fonts = no
	show_languages = no
	show_dictionaries = no
	show_filters = no
	show_sharing = no
	show_comparison_options = no
	show_dictionary_downloads = no
	show_bookmarks = no
	show_add_bookmark = no
	show_color_picker = no
	copySelectMode = no
	freehandHighlightMode = no
	freehandEraserMode = no
	freehandHighlightColor = '#F9E2A0'
	penToolMode = no
	penEraserMode = no
	penLineWidth = Number(getValue('pen-line-width') or 3)
	@observable penSketches = getValue('pen-sketches') or {}

	blockInScroll = null
	scrollLockTimeout = null
	menuIconsTransform = 0

	booksDrawerOffset = -300
	settingsDrawerOffset = -300
	bottomDrawerOffset = 0

	@observable tabs = []
	@observable activeTabIndex = 0
	@observable isSwitchingTab = no
	tabsHydrated = no
	# Track pending switch to avoid overwriting tabs mid-sync
	switchSyncTimer = null
	switchSyncAttempts = 0
	switchSyncMaxAttempts = 20
	# Short-lived guard to ignore stale routed events after a tab switch
	routeLockUntil = 0
	routeLockTab = null

	def finishSwitchWhenSynced tab
		if !tab
			isSwitchingTab = no
			imba.commit!
			return
		# Clear any previous polling
		if switchSyncTimer
			clearTimeout(switchSyncTimer)
			switchSyncTimer = null
		switchSyncAttempts = 0

		logTabDebug 'finishSwitchWhenSynced start', {
			tab: tabSummary(tab),
			activeTabIndex,
			reader: readerSummary
		}

		const check = do
			switchSyncAttempts++
			if reader.translation == tab.translation and reader.book == tab.book and reader.chapter == tab.chapter
				logTabDebug 'finishSwitchWhenSynced done', {
					tab: tabSummary(tab),
					attempts: switchSyncAttempts,
					reader: readerSummary
				}
				isSwitchingTab = no
				switchSyncTimer = null
				imba.commit!
				return
			if switchSyncAttempts >= switchSyncMaxAttempts
				logTabDebug 'finishSwitchWhenSynced timeout', {
					tab: tabSummary(tab),
					attempts: switchSyncAttempts,
					reader: readerSummary
				}
				isSwitchingTab = no
				switchSyncTimer = null
				imba.commit!
				return
			switchSyncTimer = setTimeout(&, 50) do
				check!

		check!
	# When a navigation starts inside a tab (e.g. modal), keep a stable target
	@observable tabUpdateTargetIndex = null

	# Build a reader path that respects /international prefix
	def readerPath translation\string, book\number, chapter\number
		const base = window.location.pathname.includes('international') ? '/international' : ''
		return "{base}/{translation}/{book}/{chapter}/"

	# Apply a tab's state to the reader and URL in a stable order
	def applyTabToReader tab, source\string = 'unknown'
		logTabDebug 'applyTabToReader', {
			source,
			tab: tabSummary(tab),
			activeTabIndex,
			tabUpdateTargetIndex,
			isSwitchingTab,
			reader: readerSummary
		}
		unless tab and tab.translation != undefined and tab.book != undefined and tab.chapter != undefined
			logTabDebug 'applyTabToReader skipped (missing tab data)', { tab: tabSummary(tab) }
			return
		const path = readerPath(tab.translation, tab.book, tab.chapter)
		window.history.replaceState({}, '', window.location.origin + path)
		reader.translation = tab.translation
		reader.book = tab.book
		reader.chapter = tab.chapter

	# In-memory chapter cache to avoid blanking on tab switch
	chapterCache = {}

	def chapterCacheKey translation\string, book\number, chapter\number
		return "{translation}:{book}:{chapter}"

	def cacheChapterState translation\string, book\number, chapter\number, verses, bookmarks, freehandHighlights
		const key = chapterCacheKey(translation, book, chapter)
		chapterCache[key] = {
			verses: Array.isArray(verses) ? verses.slice() : []
			bookmarks: Array.isArray(bookmarks) ? bookmarks.slice() : []
			freehandHighlights: Array.isArray(freehandHighlights) ? freehandHighlights.slice() : []
		}

	def getCachedChapter translation\string, book\number, chapter\number
		const key = chapterCacheKey(translation, book, chapter)
		return chapterCache[key]

	def loadTabs
		tabsHydrated = no
		let savedTabs = getValue('tabs')
		tabs = Array.isArray(savedTabs) ? savedTabs : []
		
		let savedIndex = getValue('activeTabIndex')
		activeTabIndex = typeof savedIndex === 'number' ? savedIndex : 0
		
		# If no tabs, create the first one from existing storage or defaults
		if tabs.length == 0
			const t = getValue('translation') || 'NVI'
			const b = getValue('book') || 1
			const c = getValue('chapter') || 1
			tabs.push({
				translation: t
				book: b
				chapter: c
				name: "{getBookName(t, b)} {c}"
			})
			setValue('tabs', tabs)
		
		# Ensure index is valid
		if activeTabIndex >= tabs.length
			activeTabIndex = 0
		if activeTabIndex < 0
			activeTabIndex = 0
		# On startup, tabs are source of truth. Sync reader from active tab before autoruns update tab names.
		const activeTab = tabs[activeTabIndex]
		if activeTab and activeTab.translation != undefined and activeTab.book != undefined and activeTab.chapter != undefined
			reader.translation = activeTab.translation
			reader.book = activeTab.book
			reader.chapter = activeTab.chapter
		tabUpdateTargetIndex = null
		tabsHydrated = yes

	def saveTabs
		setValue('tabs', tabs)
		setValue('activeTabIndex', activeTabIndex)

	def addTab
		const current = reader
		# Any previous targeted update is stale once we create a new active tab.
		tabUpdateTargetIndex = null
		logTabDebug 'addTab', {
			activeTabIndex,
			reader: readerSummary
		}
		tabs.push({
			translation: current.translation
			book: current.book
			chapter: current.chapter
			name: "{reader.nameOfCurrentBook} {reader.chapter}"
		})
		activeTabIndex = tabs.length - 1
		saveTabs!
		imba.commit!

	def switchTab index
		if index >= 0 and index < tabs.length
			# Switching tabs should always update the destination active tab only.
			tabUpdateTargetIndex = null
			const tab = tabs[index]
			unless tab
				return
			logTabDebug 'switchTab start', {
				fromIndex: activeTabIndex,
				toIndex: index,
				tab: tabSummary(tab),
				tabUpdateTargetIndex,
				reader: readerSummary
			}
			routeLockUntil = Date.now() + 800
			routeLockTab = {
				translation: tab.translation
				book: tab.book
				chapter: tab.chapter
			}
			isSwitchingTab = yes
			applyTabToReader(tab, 'switchTab')
			activeTabIndex = index
			saveTabs!
			finishSwitchWhenSynced(tab)
			imba.commit!

	def closeTab index
		if tabs.length > 1
			# Closing tabs invalidates any pending targeted index.
			tabUpdateTargetIndex = null
			logTabDebug 'closeTab start', {
				index,
				activeTabIndex,
				tabsLength: tabs.length
			}
			isSwitchingTab = yes
			tabs.splice(index, 1)
			let newIndex = activeTabIndex
			if newIndex >= tabs.length
				newIndex = tabs.length - 1
			if newIndex < 0
				newIndex = 0
			const tab = tabs[newIndex]
			logTabDebug 'closeTab apply', {
				newIndex,
				tab: tabSummary(tab)
			}
			routeLockUntil = Date.now() + 800
			routeLockTab = {
				translation: tab.translation
				book: tab.book
				chapter: tab.chapter
			}
			applyTabToReader(tab, 'closeTab')
			activeTabIndex = newIndex
			saveTabs!
			finishSwitchWhenSynced(tab)
			imba.commit!

	@autorun def updateCurrentTabName
		if !tabsHydrated
			logTabDebug 'updateCurrentTabName skipped (tabs not hydrated)', {
				activeTabIndex,
				tabUpdateTargetIndex
			}
			return
		if isSwitchingTab
			logTabDebug 'updateCurrentTabName skipped (switching)', {
				activeTabIndex,
				tabUpdateTargetIndex,
				reader: readerSummary
			}
			return
		# If a stale target points to another tab while no modal flow is active,
		# clear it so normal navigation updates only the active tab.
		if tabUpdateTargetIndex != null and tabUpdateTargetIndex != activeTabIndex and activeModal == ''
			logTabDebug 'updateCurrentTabName clear stale target', {
				activeTabIndex,
				tabUpdateTargetIndex
			}
			tabUpdateTargetIndex = null
		const index = tabUpdateTargetIndex != null ? tabUpdateTargetIndex : activeTabIndex
		const tab = tabs[index]
		unless tab and reader..nameOfCurrentBook
			logTabDebug 'updateCurrentTabName skipped (missing)', {
				index,
				activeTabIndex,
				tabUpdateTargetIndex,
				reader: readerSummary
			}
			return
		const newName = "{reader.nameOfCurrentBook} {reader.chapter}"
		if tab.name == newName and tab.translation == reader.translation and tab.book == reader.book and tab.chapter == reader.chapter
			if tabUpdateTargetIndex != null and tabUpdateTargetIndex == index
				logTabDebug 'updateCurrentTabName clear target (already in sync)', {
					index,
					activeTabIndex,
					tabUpdateTargetIndex,
					tab: tabSummary(tab),
					reader: readerSummary
				}
				tabUpdateTargetIndex = null
			return
		logTabDebug 'updateCurrentTabName', {
			index,
			tabUpdateTargetIndex,
			tabBefore: tabSummary(tab),
			reader: readerSummary,
			newName
		}
		tabs[index] = {
			name: newName
			translation: reader.translation
			book: reader.book
			chapter: reader.chapter
		}
		saveTabs!
		if tabUpdateTargetIndex != null and tabUpdateTargetIndex == index
			tabUpdateTargetIndex = null

	@observable selectedVerses\number[] = []
	@observable selectedVersesPKs\number[] = []
	@observable copySelectedVersesPKs\number[] = []
	@observable copySelectStartPK\number = 0
	@observable copySelectEndPK\number = 0
	@observable copySelectModeReader = null # Track which reader (main or parallel) is active for copy-select
	# Per-reader copy-select tracking for parallel view
	@observable copySelectStartPKMain\number = 0
	@observable copySelectEndPKMain\number = 0
	@observable copySelectStartPKParallel\number = 0
	@observable copySelectEndPKParallel\number = 0
	@observable copySelectDragging = no
	@observable copySelectDragHandle = '' # 'top' or 'bottom'
	copySelectReader = null
	selectedParallel = undefined
	selectedCategories = []

	activeModal = ''
	activeVerseAction = ''
	isVerseActionsMinimized = no
	isFreehandHighlightMinimized = no
	highlight_color\string = ''

	note = ''
	newCategoryName = ''

	@observable activeParallelAtBooksDrawer = no

	# Clean all the variables in order to free space around the text
	@action def cleanUp { onPopState } = {}
		if activeModal == 'theme'
			if theme.theme != 'custom'
				customTheme.cleanUpCustomTheme!
			if #hadTransitionsEnabled
				document.documentElement.dataset.transitions = 'true'

		# If user write a note then instead of clearing everything just hide the note panel.
		if activeModal == "notes"
			activeModal = ''
			return

		if (activeModal and not onPopState) or selectedVerses.length > 0
			window.history.back()

		show_accents = no
		show_themes = no
		show_fonts = no
		show_languages = no
		show_dictionaries = no
		show_filters = no
		show_sharing = no
		show_bookmarks = no
		show_comparison_options = no
		show_color_picker = no

		booksDrawerOffset = -300
		settingsDrawerOffset = -300
		menuIconsTransform = 0

		dictionary.tooltip = null
		dictionary.loading = no
		dictionary.definitions = []

		selectedVerses = []
		selectedVersesPKs = []
		selectedParallel = undefined
		selectedCategories = []
		copySelectedVersesPKs = []
		copySelectStartPK = 0
		copySelectEndPK = 0
		copySelectModeReader = null
		copySelectStartPKMain = 0
		copySelectEndPKMain = 0
		copySelectStartPKParallel = 0
		copySelectEndPKParallel = 0
		copySelectDragging = no
		copySelectDragHandle = ''
		copySelectReader = null
		freehandHighlightMode = no
		freehandEraserMode = no
		penToolMode = no
		penEraserMode = no

		reader.show_verse_picker = no
		parallelReader.show_verse_picker = no

		search.currentQuery = ""
		if search.inputElement
			search.inputElement.blur()

		# unless the user is typing something focus the reader in order to enable arrow navigation on the text
		unless pageSearch.on 
			# focus()
			window.getSelection().removeAllRanges()
		if pageSearch.on || activeModal
			pageSearch.on  = no
			pageSearch.matches = []
			pageSearch.rects = []

		activeModal = ''
		activeVerseAction = ''
		selectedParallel = undefined
		imba.commit!

	def toggleFreehandHighlightMode
		freehandHighlightMode = !freehandHighlightMode
		isFreehandHighlightMinimized = no
		if freehandHighlightMode
			# Keep classic highlighter defaults; pen-only colors (black/red) should not carry over.
			if freehandHighlightColor == '#000000' or freehandHighlightColor == '#DC2626'
				freehandHighlightColor = '#F9E2A0'
			penToolMode = no
			# Clear verse selection and hide regular slideup
			selectedVerses = []
			selectedVersesPKs = []
			selectedParallel = undefined
			activeVerseAction = ''
			show_sharing = no
			show_bookmarks = no
			show_add_bookmark = no
			window.getSelection().removeAllRanges()
		else
			freehandEraserMode = no
		imba.commit!

	def togglePenToolMode
		penToolMode = !penToolMode
		isFreehandHighlightMinimized = no
		if penToolMode
			# Pen tool starts from black by default.
			freehandHighlightColor = '#000000'
			freehandHighlightMode = no
			freehandEraserMode = no
			penEraserMode = no
			selectedVerses = []
			selectedVersesPKs = []
			selectedParallel = undefined
			activeVerseAction = ''
			show_sharing = no
			show_bookmarks = no
			show_add_bookmark = no
			window.getSelection().removeAllRanges()
		imba.commit!

	def penSketchKey translation\string, book\number, chapter\number
		return "{translation}:{book}:{chapter}"

	def getPenSketchesFor translation\string, book\number, chapter\number
		const key = penSketchKey(translation, book, chapter)
		const arr = penSketches and penSketches[key]
		return Array.isArray(arr) ? arr : []

	def savePenSketches
		setValue('pen-sketches', penSketches)

	def addPenSketch translation\string, book\number, chapter\number, sketch
		if !sketch
			return
		const key = penSketchKey(translation, book, chapter)
		const next = getPenSketchesFor(translation, book, chapter).slice()
		next.push(sketch)
		penSketches = {
			...(penSketches or {})
			[key]: next
		}
		savePenSketches!
		imba.commit!

	def setPenSketchesFor translation\string, book\number, chapter\number, sketches
		const key = penSketchKey(translation, book, chapter)
		const nextList = Array.isArray(sketches) ? sketches : []
		if nextList.length == 0
			return clearPenSketchesFor(translation, book, chapter)
		penSketches = {
			...(penSketches or {})
			[key]: nextList
		}
		savePenSketches!
		imba.commit!

	def clearPenSketchesFor translation\string, book\number, chapter\number
		const key = penSketchKey(translation, book, chapter)
		if !(penSketches and penSketches[key])
			return
		let next = { ...(penSketches or {}) }
		delete next[key]
		penSketches = next
		savePenSketches!
		imba.commit!


	def toggleBooksMenu parallel
		console.log('[DEBUG] toggleBooksMenu called:', {
			activeModal,
			selectedVersesPKs: selectedVersesPKs.length,
			selectedVerses: selectedVerses.length,
			parallel,
			readerBook: reader.book,
			readerChapter: reader.chapter
		})
		
		if activeModal == 'books'
			console.log('[DEBUG] Closing books modal')
			cleanUp!
		else
			# Check if we have a verse selected - if so, preserve it and show chapter view
			const hadSelectedVerses = selectedVersesPKs.length > 0
			const preservedSelectedVerses = hadSelectedVerses ? [...selectedVersesPKs] : []
			const preservedSelectedVersesNumbers = hadSelectedVerses ? [...selectedVerses] : []
			const preservedSelectedParallel = hadSelectedVerses ? selectedParallel : undefined
			
			console.log('[DEBUG] Opening books modal:', {
				hadSelectedVerses,
				currentBook: reader.book,
				currentChapter: reader.chapter
			})
			
			# Open the modal first
			openModal 'books'
			
			# Restore selections if they existed (after opening modal)
			if hadSelectedVerses
				selectedVersesPKs = preservedSelectedVerses
				selectedVerses = preservedSelectedVersesNumbers
				selectedParallel = preservedSelectedParallel
				console.log('[DEBUG] Restored selections:', {
					selectedVersesPKs: selectedVersesPKs.length,
					selectedVerses: selectedVerses.length
				})
		
		if typeof parallel == 'boolean'
			activeParallelAtBooksDrawer = parallel

	def toggleSettingsMenu
		if settingsDrawerOffset
			if !booksDrawerOffset && hasTouchEvents
				return cleanUp!
			settingsDrawerOffset = 0
		else
			imba.commit!.then do
				settingsDrawerOffset = -300
				imba.commit!

	def openModal modal_name\string
		if activeModal !== modal_name
			activeModal = modal_name
			window.history.pushState({}, modal_name)

	@action def showHelp
		cleanUp!
		openModal 'help'

	@action def showSupport
		cleanUp!
		openModal 'support'

	@action def showFonts
		cleanUp!
		openModal 'font'

	@action def showHistory
		cleanUp!
		readingHistory.syncHistory!
		openModal 'history'
	
	@action def showBookmarksModal
		cleanUp!
		openModal 'bookmarks'

	@action def showSearch
		cleanUp!
		openModal 'search'
		search.generateSuggestions!
		setTimeout(&, 300) do
			if search.inputElement
				search.inputElement.focus!

	@action def openCustomTheme
		cleanUp!
		openModal 'theme'
		#hadTransitionsEnabled = theme.transitions
		document.documentElement.dataset.transitions = 'false'

	@action def toggleDownloads
		cleanUp!
		openModal 'downloads'
		show_dictionary_downloads = no

	def getSelectedVersesTitle translation\string, book\number, chapter\number, verses\number[]
		let row = getBookName(translation, book) + ' ' + chapter + ':'
		for id, key in verses.sort(do |a, b| return a - b)
			if id == verses[key - 1] + 1
				if id == verses[key+1] - 1
					continue
				else row += '-' + id
			else
				unless key
					row += id
				else row += ',' + id
		return row

	@computed get selectedVersesTitle
		if selectedParallel == 'main'
			return getSelectedVersesTitle(reader.translation, reader.book, reader.chapter, selectedVerses) + ' ' + reader.translation
		return
			getSelectedVersesTitle(parallelReader.translation, parallelReader.book, parallelReader.chapter, selectedVerses) + ' ' + parallelReader.translation

	def compareVersesTitle versesToCompare
		return getSelectedVersesTitle(reader.translation, reader.book, reader.chapter, versesToCompare) + ' ' + reader.translation

	get randomColor
		if highlightColors and highlightColors.length
			return highlightColors[Math.floor(Math.random() * highlightColors.length)]
		const randomL = Math.random() * 0.6 + 0.2 # Range [0.2, 0.8]
		const randomC = Math.random() * 0.25 + 0.05 # Range [0.05, 0.3]
		const randomH = Math.random() * 360 # Range [0, 360)
		const randomColor = new Color('oklch', [randomL, randomC, randomH])
		return randomColor.to('hsl').toString()

	def changeHighlightColor color\string
		# get tag with title = color
		let colorBulb = document.querySelector('li.color-option[title="' + color + '"]')
		if !colorBulb
			return
		
		const computedStyle = window.getComputedStyle(colorBulb)
		const backgroundColor = computedStyle.getPropertyValue('background-color');

		highlight_color = backgroundColor
		
		# If selectedParallel is undefined but we have selectedVersesPKs, try to determine which reader
		# This can happen if the click handler cleared selectedParallel but not selectedVersesPKs
		if !selectedParallel and selectedVersesPKs.length > 0
			# Check if any of the selected verses are in the main reader
			let hasMainVerses = reader.verses.some(do |v| return selectedVersesPKs.includes(v.pk))
			if hasMainVerses
				selectedParallel = 'main'
			else
				let hasParallelVerses = parallelReader.verses.some(do |v| return selectedVersesPKs.includes(v.pk))
				if hasParallelVerses
					selectedParallel = parallelReader
		
		# Immediately apply highlight preview and save
		if selectedVersesPKs.length > 0
			if selectedParallel == 'main'
				reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				reader.saveBookmark!
			else if selectedParallel
				parallelReader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				parallelReader.saveBookmark!
			else
				# Fallback: try both readers
				reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				reader.saveBookmark!

	def setHighlightColor event
		if event.detail
			highlight_color = event.detail
			
			# Immediately apply highlight preview (for live preview while dragging)
			if selectedVersesPKs.length > 0
				if selectedParallel == 'main'
					reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				else
					parallelReader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				
				# Only save and clear selection if color picker is closed (user clicked OK or Cancel)
				# closePicker sets show_color_picker = false BEFORE emitting change event
				# Use a microtask to ensure the flag has been updated
				if !show_color_picker
					# Save the highlight before clearing selection
					if selectedParallel == 'main'
						reader.saveBookmark!
					else
						parallelReader.saveBookmark!
	
	def cleanUpCopyText text\string = ''
		let res = text.trim()
		if !settings.verse_commentary
			# remove <sup> tags with their content
			res = res.replace(/<sup>.*?<\/sup>/gi, '')
		# Remove all HTML tags and <s> tags
		return res.replace(/<s>\w+<\/s>/gi, '').replace(/<[^>]*>/gi, '')

	def cleanUpCopyTexts texts\string[]
		return cleanUpCopyText(texts.join(' '))

	get copyObject\CopyObject
		const selectedReader = selectedParallel == reader.me ? reader : parallelReader
		let verses = []
		let texts = []
		for verse in selectedReader.verses
			if selectedVersesPKs.find(do |element| return element == verse.pk)
				texts.push(verse.text)
				verses.push(verse.verse)
		return {
			title: selectedReader.selectedVersesTitle,
			text: cleanUpCopyTexts(texts),
			verses: verses,
			translation: selectedReader.translation,
			book: selectedReader.book,
			chapter: selectedReader.chapter
		}

	def fallbackCopyTextToClipboard text\string
		let textArea = document.createElement("textarea")
		textArea.value = text
		textArea.style.top = "0"
		textArea.style.left = "0"
		textArea.style.position = "fixed"

		document.body.appendChild(textArea)
		textArea.focus()
		textArea.select()

		try
			let successful = document.execCommand('copy')
			let msg = successful ? 'successful' : 'unsuccessful'
			console.log('Fallback: Copying text command was ' + msg)
		catch err
			console.error('Fallback: Oops, unable to copy', err)

		document.body.removeChild(textArea)
		notifications.push('copied')


	def copyTextToClipboard text\string
		if !window.navigator.clipboard
			fallbackCopyTextToClipboard(text)
			return
		window.navigator.clipboard.writeText(text).catch(do |err|
			console.error('Async: Could not copy text: ', err)
			fallbackCopyTextToClipboard(text)
		)
		notifications.push('copied')

	def copyToClipboard 
		let text = '«' + copyObject.text + '»\n\n' + copyObject.title
		copyTextToClipboard(text)

	# returns a string with the range of verses in format 1-3 or 1
	def versesRange verses\number[]
		verses.length > 1 ? (verses.sort(do |a, b| return a - b)[0] + '-' + verses.sort(do |a, b| return b - a)[0]) : verses[0]

	def copyWithoutLink 
		copyTextToClipboard
			'«' + copyObject.text + '»\n\n' + copyObject.title + ' ' + copyObject.translation
		cleanUp!

	def copyWithLink copy\CopyObject
		copyTextToClipboard
			'«' + cleanUpCopyText(copy.text) + '»\n\n' + copy.title + ' ' + copy.translation + ' ' + "https://bolls.life" + '/'+ copy.translation + '/' + copy.book + '/' + copy.chapter + '/' + versesRange(copy.verses) + '/'

	def copyWithInternationalLink
		copyTextToClipboard
			'«' + copyObject.text + '»\n\n' + copyObject.title + ' ' + copyObject.translation + ' ' + "https://bolls.life/international" + '/'+ copyObject.translation + '/' + copyObject.book + '/' + copyObject.chapter + '/' + versesRange(copyObject.verses) + '/'
		cleanUp!


	def copyToClipboardFromSearch copy\Verse
		copyWithLink {
			text: cleanUpCopyTexts([copy.text]),
			translation: copy.translation,
			book: copy.book,
			chapter: copy.chapter,
			verses: [copy.verse],
			title: getSelectedVersesTitle(copy.translation, copy.book, copy.chapter, [copy.verse])
		}

	def toggleBookmarks
		show_bookmarks = !show_bookmarks

	def addNewCategory
		if user.categories.includes(newCategoryName) || selectedCategories.includes(newCategoryName)
			notifications.push('category_exists')
			return
		if newCategoryName
			selectedCategories.push(newCategoryName)
		newCategoryName = ""
		show_add_bookmark = no
		show_bookmarks = no

	def addCategoryToSelected category\string
		if selectedCategories.includes(category)
			selectedCategories = selectedCategories.filter(do |element| return element != category)
		else
			selectedCategories.push(category)

	def saveBookmark
		if selectedParallel == 'main'
			reader.saveBookmark!
		else
			parallelReader.saveBookmark!


const activities = new Activities()
activities.loadTabs()

export default activities
