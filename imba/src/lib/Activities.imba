import Color from "colorjs.io"

import readingHistory from './ReadingHistory'
import { hasTouchEvents } from '../constants'

import { getBookName } from '../utils'

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

	blockInScroll = null
	scrollLockTimeout = null
	menuIconsTransform = 0

	booksDrawerOffset = -300
	settingsDrawerOffset = -300
	bottomDrawerOffset = 0

	@observable selectedVerses\number[] = []
	@observable selectedVersesPKs\number[] = []
	@observable copySelectedVersesPKs\number[] = []
	@observable copySelectStartPK\number = 0
	@observable copySelectEndPK\number = 0
	@observable copySelectModeReader = null # Track which reader (main or parallel) is active for copy-select
	@observable copySelectDragging = no
	@observable copySelectDragHandle = '' # 'top' or 'bottom'
	copySelectReader = null
	selectedParallel = undefined
	selectedCategories = []

	activeModal = ''
	activeVerseAction = ''
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
		copySelectDragging = no
		copySelectDragHandle = ''
		copySelectReader = null

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


	def toggleBooksMenu parallel
		if booksDrawerOffset
			if !settingsDrawerOffset && hasTouchEvents
				return cleanUp!
			booksDrawerOffset = 0
		else
			imba.commit!.then do
				booksDrawerOffset = -300
				imba.commit!
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
		const randomL = Math.random() * 0.6 + 0.2 # Range [0.2, 0.8]
		const randomC = Math.random() * 0.25 + 0.05 # Range [0.05, 0.3]
		const randomH = Math.random() * 360 # Range [0, 360)
		const randomColor = new Color('oklch', [randomL, randomC, randomH])
		return randomColor.to('hsl').toString()

	def changeHighlightColor color\string
		# get tag with title = color
		console.log('[changeHighlightColor] Called with color name:', color)
		console.log('[changeHighlightColor] Current state - selectedVersesPKs:', selectedVersesPKs)
		console.log('[changeHighlightColor] Current state - selectedVerses:', selectedVerses)
		console.log('[changeHighlightColor] Current state - selectedParallel:', selectedParallel)
		console.log('[changeHighlightColor] Current state - activeVerseAction:', activeVerseAction)
		
		let colorBulb = document.querySelector('li.color-option[title="' + color + '"]')
		if !colorBulb
			console.warn('[changeHighlightColor] Color bulb not found for:', color)
			return
		
		const computedStyle = window.getComputedStyle(colorBulb)
		const backgroundColor = computedStyle.getPropertyValue('background-color');
		console.log('[changeHighlightColor] Computed background color:', backgroundColor)

		highlight_color = backgroundColor
		console.log('[changeHighlightColor] Updated highlight_color to:', highlight_color)
		console.log('[changeHighlightColor] Selected verses PKs after update:', selectedVersesPKs)
		
		# If selectedParallel is undefined but we have selectedVersesPKs, try to determine which reader
		# This can happen if the click handler cleared selectedParallel but not selectedVersesPKs
		if !selectedParallel and selectedVersesPKs.length > 0
			console.log('[changeHighlightColor] selectedParallel is undefined, checking which reader has these verses')
			# Check if any of the selected verses are in the main reader
			let hasMainVerses = reader.verses.some(do |v| return selectedVersesPKs.includes(v.pk))
			if hasMainVerses
				console.log('[changeHighlightColor] Setting selectedParallel to main')
				selectedParallel = 'main'
			else
				let hasParallelVerses = parallelReader.verses.some(do |v| return selectedVersesPKs.includes(v.pk))
				if hasParallelVerses
					console.log('[changeHighlightColor] Setting selectedParallel to parallel reader')
					selectedParallel = parallelReader
		
		# Immediately apply highlight preview
		if selectedVersesPKs.length > 0
			console.log('[changeHighlightColor] Applying immediate highlight preview with selectedParallel:', selectedParallel)
			if selectedParallel == 'main'
				reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
			else if selectedParallel
				parallelReader.applyHighlightPreview(selectedVersesPKs, highlight_color)
			else
				# Fallback: try both readers
				console.warn('[changeHighlightColor] selectedParallel is still undefined, trying main reader')
				reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
			
			# Always clear selection after applying highlight (preset colors don't use picker)
			console.log('[changeHighlightColor] Clearing selection after applying highlight')
			selectedVerses = []
			selectedVersesPKs = []
			selectedParallel = undefined
			activeVerseAction = undefined
			imba.commit!
		else
			console.warn('[changeHighlightColor] No verses selected, cannot apply highlight')
			console.warn('[changeHighlightColor] This might be a timing issue - checking if we can get verses from DOM')
			# Try to get selected verses from the DOM as a fallback
			let selectedElements = document.querySelectorAll('.selected-verse')
			console.log('[changeHighlightColor] Found selected-verse elements in DOM:', selectedElements.length)

	def setHighlightColor event
		console.log('[setHighlightColor] Called with event:', event)
		if event.detail
			highlight_color = event.detail
			console.log('[setHighlightColor] Updated highlight_color to:', highlight_color)
			console.log('[setHighlightColor] Selected verses PKs:', selectedVersesPKs)
			console.log('[setHighlightColor] Color picker open:', show_color_picker)
			
			# Immediately apply highlight preview (for live preview while dragging)
			if selectedVersesPKs.length > 0
				console.log('[setHighlightColor] Applying immediate highlight preview')
				if selectedParallel == 'main'
					reader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				else
					parallelReader.applyHighlightPreview(selectedVersesPKs, highlight_color)
				
				# Only clear selection if color picker is closed (user clicked OK or Cancel)
				# closePicker sets show_color_picker = false BEFORE emitting change event
				# Use a microtask to ensure the flag has been updated
				if !show_color_picker
					console.log('[setHighlightColor] Color picker closed, clearing selection after applying highlight')
					# Use Promise.resolve().then to ensure this runs after the current event loop
					Promise.resolve().then do
						selectedVerses = []
						selectedVersesPKs = []
						selectedParallel = undefined
						activeVerseAction = undefined
						imba.commit!
				else
					console.log('[setHighlightColor] Color picker still open, keeping selection for live preview')
			else
				console.warn('[setHighlightColor] No verses selected, cannot apply highlight')
		else
			console.warn('[setHighlightColor] No color detail in event')
	
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

export default activities
