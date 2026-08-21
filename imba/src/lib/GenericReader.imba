import { getValue, setValue, deleteValue } from '../utils'

import ALL_BOOKS from '../data/translations_books.json'

import API from './Api'
import theme from './Theme'
import settings from './Settings'
import activities from './Activities'
import user from './User'
import vault from './Vault'
import notifications from './Notifications'

import reader from './Reader'
import parallelReader from './ParallelReader'

import type { Verse, Bookmark } from './types'

const BOOKMARK_MARKER = '__bolls_bookmark__'

class GenericReader
	@observable translation\string
	@observable book\number
	@observable chapter\number
	verses\Array<Verse> = []
	loading\boolean = no
	@observable bookmarks\Bookmark[] = []
	@observable freehandHighlights = []
	freehandSaveInFlight = no
	freehandPendingSaveRequest = null
	show_verse_picker\boolean = no
	verse\number|string = 0
	_verseNavToken = 0
	# Set before a chapter change to center the verse once the new chapter has loaded
	centerNextVerseNav = no

	me = '' # constant to indicate the main reader versus the parallel reader
	def hasBookmarkMarker collection\string
		if !collection
			return no
		return String(collection).split(' | ').includes(BOOKMARK_MARKER)

	def stripBookmarkMarker collection\string
		if !collection
			return ''
		return String(collection)
			.split(' | ')
			.map(do |piece| return piece.trim!)
			.filter(do |piece| return piece != '' and piece != BOOKMARK_MARKER)
			.join(' | ')

	def mergeBookmarkMarker collection\string, bookmarked\boolean
		let parts = []
		if collection
			parts = String(collection)
				.split(' | ')
				.map(do |piece| return piece.trim!)
				.filter(do |piece| return piece != '' and piece != BOOKMARK_MARKER)
		if bookmarked
			parts.push(BOOKMARK_MARKER)
		return parts.join(' | ')

	def isExplicitBookmarkEntry item
		if !item
			return no
		const color = item.color and String(item.color).trim()
		if !color
			return yes
		return hasBookmarkMarker(item.collection or '')

	@computed get books
		unless ALL_BOOKS[translation]
			return ALL_BOOKS['YLT']
		let orderBy = settings.chronorder ? 'chronorder' : 'bookid'
		return ALL_BOOKS[translation].sort(do(a, b) return a[orderBy] - b[orderBy])

	@computed get nameOfCurrentBook
		for tr_book in books
			if tr_book.bookid == book
				return tr_book.name
		return book
	
	def theChapterExistInThisTranslation book\number, chapter\number
		const theBook = books.find(do |element| return element.bookid == book)
		if theBook
			if theBook.chapters >= chapter
				return yes
		return no

	# Pick a valid book/chapter for the target translation (same book when possible).
	def normalizedPlaceForTranslation translation\string, book\number, chapter\number
		let bookList = ALL_BOOKS[translation]
		unless bookList and bookList.length
			return null
		let nextBook = book
		let nextChapter = chapter
		let bookEntry = bookList.find(do |b| return b.bookid == nextBook)
		unless bookEntry
			bookEntry = bookList[0]
			nextBook = bookEntry.bookid
			nextChapter = 1
		else
			if nextChapter < 1
				nextChapter = 1
			elif nextChapter > bookEntry.chapters
				nextChapter = bookEntry.chapters
		return { book: nextBook, chapter: nextChapter }

	@action def applyTranslationChange nextTranslation\string
		unless nextTranslation
			return no
		let place = normalizedPlaceForTranslation(nextTranslation, book, chapter)
		unless place
			notifications.push('error')
			return no
		self.translation = nextTranslation
		self.book = place.book
		self.chapter = place.chapter
		self.verse = undefined
		if me == 'main' and activities
			const path = activities.readerPath(nextTranslation, place.book, place.chapter)
			window.history.replaceState({}, '', window.location.origin + path)
			syncMainTabState!
		return yes

	# Navigate to book/chapter and optionally select a verse after load.
	# When only the verse changes within the current chapter, fetchVerses does not
	# re-run (verse is not observable), so we select immediately in that case.
	@action def navigateToPlace bookid\number, chapter\number, verseNum\number|string = null
		++self._verseNavToken
		const wasSamePlace = self.book == bookid and self.chapter == chapter

		if verseNum != null and verseNum != undefined and verseNum != ''
			self.verse = verseNum
		else
			self.verse = undefined

		unless wasSamePlace
			self.book = bookid
			self.chapter = chapter
			return

		if self.verse
			const token = ++self._verseNavToken
			goToAndSelectVerse(self.verse, null, token)
			self.verse = undefined

	@action def ensureValidChapterForTranslation
		unless theChapterExistInThisTranslation book, chapter
			let place = normalizedPlaceForTranslation(translation, book, chapter)
			unless place
				return no
			self.book = place.book
			self.chapter = place.chapter
		return yes

	@computed get chaptersOfCurrentBook
		for book in books
			if book.bookid == self.book
				return book.chapters
	
	@action def nextChapter
		freehandHighlights = []
		if chapter + 1 <= chaptersOfCurrentBook
			chapter += 1
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index + 1]
				book = books[current_index + 1].bookid
				chapter = 1
		syncMainTabState!

	@action def prevChapter
		freehandHighlights = []
		if chapter - 1 > 0
			chapter -= 1
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index - 1]
				book = books[current_index - 1].bookid
				chapter = books[current_index - 1].chapters
		syncMainTabState!

	def syncMainTabState
		if me == 'main' and activities and activities.applyTabStateFromReader
			activities.applyTabStateFromReader(null, 'reader-nav')

	@computed get prevChapterLink
		if chapter - 1 > 0
			return "/{translation}/{book}/{chapter - 1}/"
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index - 1]
				return "/{translation}/{books[current_index - 1].bookid}/{books[current_index - 1].chapters}/"
		return "/{translation}/{book}/{chapter}/" # default plug

	@computed get nextChapterLink
		if chapter + 1 <= chaptersOfCurrentBook
			return "/{translation}/{book}/{chapter + 1}/"
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index + 1]
				return "/{translation}/{books[current_index+1].bookid}/1/"
		return "/{translation}/{book}/{chapter}/" # default plug

	@action def nextBook
		freehandHighlights = []
		let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
		if books[current_index + 1]
			book = books[current_index + 1].bookid
			chapter = 1
		syncMainTabState!

	@action def prevBook
		freehandHighlights = []
		let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
		if books[current_index - 1]
			book = books[current_index - 1].bookid
			chapter = 1
		syncMainTabState!

	def getBookmark verseNumber\number
		if user.username
			return bookmarks.find(do |element| return element.verse == verseNumber)

	# Bookmark-only (no highlight): used for showing the red bookmark icon on the verse. Highlights must not show the icon.
	def getBookmarkOnly verseNumber\number
		if !user.username
			return null
		let b = bookmarks.find(do |element| return element.verse == verseNumber)
		if !b
			return null
		# Highlight-only entries are not bookmarks unless explicitly marked.
		if !isExplicitBookmarkEntry(b)
			return null
		return b

	def startVerseNoteLinks verseNumber\number
		return activities.linksCoveringVerse(translation, book, chapter, verseNumber)

	def openVerseNoteLinks verseNumber\number
		activities.openVerseNoteLinks(translation, book, chapter, verseNumber)

	def getHighlight pk\number
		# Don't return background for selected verses - they use text color instead
		let highlight = bookmarks.find(do |element| return element.verse == pk)
		# Bookmark-only (no color) = no background; only highlighted verses get a background
		if highlight and highlight.color and String(highlight.color).trim() != ''
			return  "linear-gradient({highlight.color} 0px, {highlight.color} 100%)"
		return ''
	
	def getHighlightTextColor pk\number
		let highlight = bookmarks.find(do |element| return element.verse == pk)
		# Bookmark-only (no color) = no text color override
		if !highlight or !highlight.color or String(highlight.color).trim() == ''
			return null
		return 'black'
	
	def applyHighlightPreview pks\number[], color\string
		# Immediately apply highlight to verses without saving to server
		# This creates a preview that will be saved when user clicks save
		if !color or color == ''
			return
		
		if !pks or pks.length == 0
			return
		
		for pk in pks
			# Merge highlight preview into existing entry so bookmark state is preserved.
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == pk)
			if existingBookmark
				existingBookmark.date = Date.now()
				existingBookmark.color = color
			else
				bookmarks.push({
					verse: pk,
					date: Date.now(),
					color: color,
					collection: '',
					note: ''
				})
		
		imba.commit!
	
	def getArticleElement
		# Get the article element for this specific reader
		# Use the me property to identify which reader (me.me is 'main' or 'parallel')
		# me is the instance, and me.me is the property value
		let readerType = self.me or ''
		
		let readerId = readerType == 'main' ? 'main-reader' : 'parallel-reader'
		
		let readerEl = document.getElementById(readerId)
		if readerEl
			let article = readerEl.querySelector('article')
			return article
		return null
	
	def getSelectionBox
		# Get the selection box for this specific reader's article
		let readerType = self.me or ''
		let articleEl = self.getArticleElement()
		if !articleEl
			return null
		let box = articleEl.querySelector('.verse-selection-box')
		return box
	
	def getCopySelectInfo pk\number
		if !activities.copySelectMode or activities.copySelectStartPK == 0
			return { inRange: no, isStart: no, isEnd: no }
		
		let startIdx = verses.findIndex(do |v| return v.pk == activities.copySelectStartPK)
		let endIdx = verses.findIndex(do |v| return v.pk == activities.copySelectEndPK)
		let currentIdx = verses.findIndex(do |v| return v.pk == pk)
		
		if startIdx == -1 or endIdx == -1 or currentIdx == -1
			return { inRange: no, isStart: no, isEnd: no }
			
		let minIdx = Math.min(startIdx, endIdx)
		let maxIdx = Math.max(startIdx, endIdx)
		
		return {
			inRange: currentIdx >= minIdx and currentIdx <= maxIdx
			isStart: currentIdx == minIdx
			isEnd: currentIdx == maxIdx
		}

	def updateCopySelectRange
		let readerType = self.me or ''
		
		# Get per-reader PKs
		let startPK = readerType == 'main' ? activities.copySelectStartPKMain : activities.copySelectStartPKParallel
		let endPK = readerType == 'main' ? activities.copySelectEndPKMain : activities.copySelectEndPKParallel
		
		# Only update if this reader has copy-select active
		if !activities.copySelectMode or startPK == 0
			let box = self.getSelectionBox()
			if box
				box.style.display = 'none'
			return
		
		let startIdx = verses.findIndex(do |v| return v.pk == startPK)
		let endIdx = verses.findIndex(do |v| return v.pk == endPK)
		
		if startIdx == -1 or endIdx == -1
			let box = self.getSelectionBox()
			if box
				box.style.display = 'none'
			return
		
		let minIdx = Math.min(startIdx, endIdx)
		let maxIdx = Math.max(startIdx, endIdx)
		activities.copySelectedVersesPKs = []
		for i in [minIdx .. maxIdx]
			if verses[i]
				activities.copySelectedVersesPKs.push(verses[i].pk)
		
		# Position the overlay box over selected verses (matches Obsidian plugin)
		window.requestAnimationFrame(do
			window.requestAnimationFrame(do
				let box = self.getSelectionBox()
				if !box
					return
				
				# Get the article container for this reader
				let articleEl = self.getArticleElement()
				if !articleEl
					box.style.display = 'none'
					return
				
				# Determine verse prefix based on reader
				let readerType = self.me or ''
				let versePrefix = readerType == 'main' ? '' : 'p'
				
				# Find verse elements
				let firstVerseEl = null
				let lastVerseEl = null
				
				for i in [minIdx .. maxIdx]
					if verses[i]
						let verseNum = verses[i].verse
						let verseId = versePrefix ? versePrefix + String(verseNum) : String(verseNum)
						
						# Try getElementById first
						let verseEl = document.getElementById(verseId)
						# Verify it's within this article
						if verseEl and articleEl.contains(verseEl)
							if !firstVerseEl
								firstVerseEl = verseEl
							lastVerseEl = verseEl
						else
							# Try querySelector within article
							verseEl = articleEl.querySelector('span[id="{verseId}"]')
						if verseEl
							if !firstVerseEl
								firstVerseEl = verseEl
							lastVerseEl = verseEl
				
				if !firstVerseEl or !lastVerseEl
					box.style.display = 'none'
					return
				
				# Calculate position relative to article
				let top = firstVerseEl.offsetTop - 4
				let bottom = lastVerseEl.offsetTop + lastVerseEl.offsetHeight + 4
				
				# Position the box
				box.style.display = 'block'
				box.style.top = "{top}px"
				box.style.height = "{bottom - top}px"
			)
		)
	
	def getBookmarks
		if !user.username
			return

		let server_bookmarks = []
		let offline_bookmarks = []
		if window.navigator.onLine
			try
				server_bookmarks = await API.getJson("/get-bookmarks/" + translation + '/' + book + '/' + chapter + '/', 'bookmarks')
			catch error
				pass

		if vault.available and Array.isArray(verses) and verses.length > 0
			offline_bookmarks = await vault.getChapterBookmarks(verses.map(do |verse| return verse.pk))

		bookmarks = offline_bookmarks.concat(server_bookmarks)
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		# So bookmark list modal shows items on load without needing another action
		window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		if activities and activities.loadVerseNoteLinks
			activities.loadVerseNoteLinks!
		imba.commit!

	def getFreehandHighlights
		loadLocalFreehandHighlights!
		if !user.username or !window.navigator.onLine
			return

		try
			freehandHighlights = await API.getJson("/get-freehand-highlights/" + translation + '/' + book + '/' + chapter + '/', 'freehandHighlights')
			saveLocalFreehandHighlights!
			if activities and activities.cacheChapterState
				activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
			imba.commit!
		catch error
			console.log "Error fetching freehand highlights:", error

	def freehandLocalStorageKey
		return "freehand-highlights:{translation}:{book}:{chapter}"

	def loadLocalFreehandHighlights
		let stored = getValue(freehandLocalStorageKey!)
		if !Array.isArray(stored)
			return
		freehandHighlights = stored.map(do |item|
			return {
				startVerse: item.startVerse
				startOffset: item.startOffset
				endVerse: item.endVerse
				endOffset: item.endOffset
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or Date.now()
			}
		)

	def saveLocalFreehandHighlights
		const now = Date.now()
		const normalized = (freehandHighlights or []).map(do |item|
			return {
				startVerse: item.startVerse
				startOffset: item.startOffset
				endVerse: item.endVerse
				endOffset: item.endOffset
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or now
			}
		)
		setValue(freehandLocalStorageKey!, normalized)

	def refreshFreehandHighlightDisplay
		if !Array.isArray(freehandHighlights) or freehandHighlights.length == 0
			return
		# Force verse HTML to rebuild mark tags after leaving freehand mode.
		freehandHighlights = freehandHighlights.slice()
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		imba.commit!

	def saveFreehandHighlights
		const now = Date.now()
		freehandHighlights = (freehandHighlights or []).map(do |item|
			return {
				startVerse: item.startVerse
				startOffset: item.startOffset
				endVerse: item.endVerse
				endOffset: item.endOffset
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or now
			}
		)
		saveLocalFreehandHighlights!
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		if !user.username or !window.navigator.onLine
			imba.commit!
			return

		# Keep only the newest pending payload; this prevents out-of-order API writes
		# from dropping recently drawn strokes when users draw quickly.
		freehandPendingSaveRequest = {
			translation: translation
			book: book
			chapter: chapter
			highlights: freehandHighlights.map(do |item|
				return {
					startVerse: item.startVerse
					startOffset: item.startOffset
					endVerse: item.endVerse
					endOffset: item.endOffset
					color: item.color
					decoration: item.decoration or 'fill'
					underlineStyle: item.underlineStyle or 'solid'
					date: item.date
				}
			)
		}
		flushFreehandSaveQueue!

	def flushFreehandSaveQueue
		if freehandSaveInFlight or !freehandPendingSaveRequest
			return
		freehandSaveInFlight = yes
		const request = freehandPendingSaveRequest
		freehandPendingSaveRequest = null
		try
			await API.post("/save-freehand-highlights/", {
				translation: request.translation
				book: request.book
				chapter: request.chapter
				highlights: request.highlights
			})
			# So Highlights and Bookmarks modal refreshes and shows new freehand
			window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		catch error
			console.log "Error saving freehand highlights:", error
		finally
			freehandSaveInFlight = no
			# If new strokes arrived while save was in flight, persist latest snapshot now.
			if freehandPendingSaveRequest
				flushFreehandSaveQueue!

	def clearAllChapterHighlights
		# Update local state first so UI (verse icons + modal list) updates instantly
		let pks = bookmarks.map(do |b| b.verse)
		const deletedColors = new Set<string>()
		for b in bookmarks
			if b.color
				deletedColors.add(b.color)
		freehandHighlights = []
		bookmarks = []
		deleteValue(freehandLocalStorageKey!)
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		for color in deletedColors
			user.deleteBookmarkFromUserMap translation, book, chapter, color
		window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		window.dispatchEvent(new CustomEvent('highlights-cache-clear'))
		activities.cleanUp!
		imba.commit!

		# Sync to API/vault in background (like add: UI first, then persist)
		if pks.length > 0
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] clearAllChapterHighlights: removing', { pks })
			requestDeleteBookmark(pks)
		saveFreehandHighlights!

	@computed get selectionHasBookmark
		for verse in activities.selectedVersesPKs
			let entry = bookmarks.find(do |element| return element.verse == verse)
			if entry and isExplicitBookmarkEntry(entry)
				return yes
		return no

	def getCollectionOfChosen verseNumber\number
		let highlight = bookmarks.find(do |element| return element.verse == verseNumber)
		if highlight
			return stripBookmarkMarker(highlight.collection)
		else ''

	def pushCollectionIfExist pk\number
		for piece in getCollectionOfChosen(pk).split(' | ')
			if piece != '' && !activities.selectedCategories.includes(piece)
				activities.selectedCategories.push(piece)


	def selectVerse pk\number, id\number, force = no
		unless force
			if !document.getSelection().isCollapsed or activities.activeModal or activities.freehandHighlightMode or activities.penToolMode
				return

		if activities.copySelectMode
			let readerType = self.me or ''
			# Switch copy-select to this reader and set the verse
			activities.copySelectModeReader = me
			# Set per-reader PKs for parallel view support
			if readerType == 'main'
				activities.copySelectStartPKMain = pk
				activities.copySelectEndPKMain = pk
			else
				activities.copySelectStartPKParallel = pk
				activities.copySelectEndPKParallel = pk
			# Also set global PKs for backward compatibility
			activities.copySelectStartPK = pk
			activities.copySelectEndPK = pk
			activities.copySelectedVersesPKs = [pk]
			self.updateCopySelectRange!
			imba.commit!
			return

		# Allow selection in parallel view - don't block if copy-select mode is active
		# If switching to a different reader, clear previous selection to allow switching sides
		if !activities.copySelectMode and activities.selectedParallel != undefined
			# Check if selectedParallel refers to a different reader
			let isDifferentReader = false
			if activities.selectedParallel == 'main' and self.me != 'main'
				isDifferentReader = true
			elif activities.selectedParallel != 'main' and activities.selectedParallel != me
				isDifferentReader = true
			
			if isDifferentReader
				# Clear previous selection to allow switching sides
				activities.selectedVersesPKs = []
				activities.selectedVerses = []
				activities.selectedCategories = []
				activities.selectedParallel = undefined
				activities.activeVerseAction = undefined

		activities.selectedParallel = me
		unless activities.highlight_color
		activities.highlight_color = activities.randomColor

		if activities.selectedVersesPKs.length == 0 && me == 'main'
			window.history.pushState(
				{},
				'',
				window.location.origin + '/' + translation + '/' + book + '/' + chapter + '/' + id + '/'
			)

		console.log('[DEBUG] selectVerse called:', {
			pk,
			id,
			alreadySelected: activities.selectedVersesPKs.includes(pk),
			currentSelectedCount: activities.selectedVersesPKs.length
		})
		
		# Check if the user chosen a verse in the same parallel scope
		if activities.selectedVersesPKs.includes(pk)
			console.log('[DEBUG] Deselecting verse:', { pk, id })
			activities.selectedVersesPKs.splice(activities.selectedVersesPKs.indexOf(pk), 1)
			activities.selectedVerses.splice(activities.selectedVerses.indexOf(id), 1)
			let collection = getCollectionOfChosen(pk)
			if collection
				for piece in collection.split(' | ')
					if piece != ''
						activities.selectedCategories.splice(activities.selectedCategories.indexOf(piece), 1)
		else
			console.log('[DEBUG] Selecting verse:', { pk, id })
			activities.selectedVersesPKs.push(pk)
			activities.selectedVerses.push(id)
			pushCollectionIfExist(pk)

		# If the verse is in area under bottom section
		# scroll to it, to see the full verse
		let verseElement
		if me == 'main'
			verseElement = document.getElementById(String(id))
		else
			verseElement = document.getElementById("p{id}")
		
		if !verseElement
			return

		const boundingRect = verseElement.getBoundingClientRect()
		const scroller = verseElement.closest('#main-reader') or verseElement.closest('#parallel-reader')
		const atBottom = scroller and (scroller.scrollHeight - scroller.clientHeight - scroller.scrollTop) <= 80
		unless atBottom
			if boundingRect.bottom + activities.bottomDrawerOffset > window.innerHeight - 124 # 124 is the relative height of the bottom drawer
				verseElement.scrollIntoView({behavior: theme.scrollBehavior, block: 'center'})

		if activities.commentaryCompareMode and me == 'main' and activities.selectedVersesPKs.length
			let verseNum = Number(id)
			if verseNum > 0
				activities.commentaryCompareVerse = verseNum

		if activities.selectedVersesPKs.length
			showDeleteBookmark()
			mergeNotes()
			# Show slideup unless it was explicitly suppressed (from modal navigation)
			# We use a special marker 'suppressed' to indicate suppression
			if activities.commentaryCompareMode and me == 'main'
				activities.activeVerseAction = 'suppressed'
			elif activities.activeVerseAction != 'suppressed'
				# Always set to 'options' for normal selections (not from modal)
				activities.activeVerseAction = 'options'
				activities.isVerseActionsMinimized = no
				activities.armBottomToolbarLift(verseElement)
				activities.playContentLift!
				console.log('[DEBUG] Showing verse-actions slideup')
			else
				console.log('[DEBUG] Verse selected but slideup suppressed (from modal navigation)')
		else
			console.log('[DEBUG] Verse deselected, hiding slideup')
			# Reset to empty string so next selection will show slideup
			activities.activeVerseAction = ''
			activities.selectedParallel = undefined
		
		imba.commit!
		if !activities.selectedVersesPKs.length or activities.activeVerseAction != 'options'
			activities.clearBottomToolbarLift!


	def mergeNotes
		activities.note = ''
		for versePK in activities.selectedVersesPKs
			let vrs = bookmarks.find(do |element| return element.verse == versePK)
			if vrs
				if activities.note.indexOf(vrs.note) < 0
					activities.note += vrs.note


	def showDeleteBookmark
		for verseNumber in activities.selectedVerses
			let vrs = bookmarks.find(do |element| return element.verse == verseNumber)
			if vrs
				return 1

	@computed get selectedVersesTitle
		let row = nameOfCurrentBook + ' ' + chapter + ':'
		for id, key in activities.selectedVerses.sort(do |a, b| return a - b)
			if id == activities.selectedVerses[key - 1] + 1
				if id == activities.selectedVerses[key+1] - 1
					continue
				else row += '-' + id
			else
				unless key
					row += id
				else row += ',' + id
		return row


	def findVerse id, endverse\string|number = undefined, highlight = no
		setTimeout(&,250) do
			const verseNumberElement = document.getElementById(id)
			if verseNumberElement
				verseNumberElement.offsetParent.scrollTo({
					behavior: theme.scrollBehavior,
					top: verseNumberElement.offsetTop - theme.fontSize
				})
				if highlight then highlightLinkedVerses(id, endverse)
			else
				findVerse(id, endverse, highlight)

	def goToAndSelectVerse verseNum, versePk\number = null, token\number = null, center\boolean = no
		unless token
			token = ++self._verseNavToken
		const shouldCenter = center or self.centerNextVerseNav
		self.centerNextVerseNav = no
		let id = typeof verseNum === 'string' ? verseNum.split('-')[0] : String(verseNum)
		let num = parseInt(id)
		let scrollId = me == 'main' ? String(num) : "p{num}"
		activities.selectedVersesPKs = []
		activities.selectedVerses = []
		activities.selectedCategories = []
		activities.selectedParallel = undefined
		activities.activeVerseAction = ''
		if window.getSelection
			window.getSelection().removeAllRanges()

		let selected = no
		const trySelect = do
			if selected or token != self._verseNavToken
				return
			let pk = versePk
			unless pk
				let v = verses.find(do |v| return v.verse == num)
				unless v
					setTimeout(trySelect, 250)
					return
				pk = v.pk
				num = v.verse
			let el = me == 'main' ? document.getElementById(String(num)) : document.getElementById("p{num}")
			unless el
				setTimeout(trySelect, 250)
				return
			selected = yes
			selectVerse(pk, num, yes)
			imba.commit!

		const afterScroll = do
			window.requestAnimationFrame do
				trySelect!

		const scrollToVerse = do
			if token != self._verseNavToken
				return
			setTimeout(&, 250) do
				if token != self._verseNavToken
					return
				let el = document.getElementById(scrollId)
				if el and el.offsetParent
					const container = el.offsetParent
					let top = el.offsetTop - theme.fontSize
					if shouldCenter
						top = el.offsetTop - Math.max(theme.fontSize, (container.clientHeight - el.offsetHeight) / 2)
					container.scrollTo({
						behavior: 'auto',
						top: Math.max(0, top)
					})
					afterScroll!
				else
					scrollToVerse()

		scrollToVerse()

	def highlightLinkedVerses verseNumber, endverse
		if !window.getSelection
			return

		setTimeout(&, 250) do
			const verseNode = document.getElementById(verseNumber)
			unless verseNode
				return highlightLinkedVerses verseNumber, endverse

			const selection = window.getSelection()
			selection.removeAllRanges()
			if endverse
				for id in [parseInt(verseNumber) .. parseInt(endverse)]
					if id <= verses.length
						const range = document.createRange()
						const node = document.getElementById(String(id))
						range.selectNodeContents(node)
						selection.addRange(range)
			else
				const range = document.createRange()
				range.selectNodeContents(verseNode)
				selection.addRange(range)

	def saveBookmark bookmarkOnly\boolean = no
		unless user.username
			window.location.pathname = "/signup/"
			return

		if activities.note == '<br>'
			activities.note = ''

		# Capture selection and state before any await — button calls cleanUp! immediately so selection would be cleared
		let selectedPKs = activities.selectedVersesPKs.slice()
		let highlightColor = activities.highlight_color
		const requestedBookmarkOnly = bookmarkOnly or !highlightColor or String(highlightColor).trim() == ''
		let selectedCategories = activities.selectedCategories.slice()
		let collections = selectedCategories.map(do(str) str.trim!).join(' | ')
		let note = activities.note
		const now = Date.now()
		let payloads = []

		# Update local bookmarks using captured selection (cleanUp may have already cleared activities.selectedVersesPKs)
		for verse in selectedPKs
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == verse)
			let finalColor = highlightColor
			if requestedBookmarkOnly and (!finalColor or String(finalColor).trim() == '') and existingBookmark and existingBookmark.color and String(existingBookmark.color).trim() != ''
				finalColor = existingBookmark.color
			let shouldKeepBookmark = requestedBookmarkOnly
			if existingBookmark and isExplicitBookmarkEntry(existingBookmark)
				shouldKeepBookmark = yes
			let finalCollectionBase = collections
			if (!finalCollectionBase or String(finalCollectionBase).trim() == '') and existingBookmark
				finalCollectionBase = stripBookmarkMarker(existingBookmark.collection)
			let finalCollection = mergeBookmarkMarker(finalCollectionBase, shouldKeepBookmark)
			let finalNote = note
			if (!finalNote or String(finalNote).trim() == '') and existingBookmark and existingBookmark.note
				finalNote = existingBookmark.note
			if existingBookmark
				existingBookmark.date = now
				existingBookmark.color = finalColor
				existingBookmark.collection = finalCollection
				existingBookmark.note = finalNote
			else
				bookmarks.push({
					verse: verse,
					date: now,
					color: finalColor,
					collection: finalCollection
					note: finalNote
				})
			payloads.push({
				verses: [verse],
				color: finalColor or '',
				date: now,
				collections: finalCollection or '',
				note: finalNote or ''
			})
		# Reassign so @observable triggers re-render (chapter + any listener) — same as highlights
		bookmarks = bookmarks.slice()
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		user.saveUserBookmarkToMap translation, book, chapter, highlightColor
		for category in selectedCategories
			if !user.categories.includes(category)
				user.categories.push(category)
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] saveBookmark: local updated, reader.bookmarks.length=', bookmarks.length, ', dispatching bookmarks-updated')
		window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		imba.commit!
		activities.cleanUp!

		# Persist per-verse to DB so highlight actions don't accidentally mark all selected verses as bookmarks.
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] saveBookmark: saving payloads to DB count=', payloads.length)
		if window.navigator.onLine
			try
				for payload in payloads
					await API.post("/save-bookmarks/", payload)
				notifications.push('saved')
			catch e
				notifications.push('error')
				if typeof console != 'undefined' and console.error
					console.error('[HIGHLIGHTS] saveBookmark: API error', e)
				if vault.available
					for payload in payloads
						vault.saveBookmarksToStorageUntilOnline(payload)
		else
			if vault.available
				for payload in payloads
					vault.saveBookmarksToStorageUntilOnline(payload)

	def requestDeleteBookmark pks\number[]
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] requestDeleteBookmark: removing from DB', { pks })
		vault.deleteBookmarks(pks)
		if window.navigator.onLine
			try
				await API.post("/delete-bookmarks/", { verses: pks })
				notifications.push('deleted')
				if typeof console != 'undefined' and console.log
					console.log('[HIGHLIGHTS] requestDeleteBookmark: removed from DB', { pks })
			catch err
				if typeof console != 'undefined' and console.error
					console.error('[HIGHLIGHTS] requestDeleteBookmark: API error', err)
				deleteLater (pks)
		else deleteLater (pks)

	def deleteLater pks\number[]
		let bookmarksToDelete = getValue('bookmarks-to-delete')
		setValue('bookmarks-to-delete', bookmarksToDelete.concat(pks))

	def deleteBookmark pks\number[]
		if !user.username
			window.location.pathname = "/signup/"
			return
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] deleteBookmark: deleting', { pks })

		# Capture colors before removing (for user map cleanup)
		const deletedColors = new Set<string>()
		for verse in activities.selectedVersesPKs
			let bookmark = bookmarks.find(do |element| return element.verse == verse)
			if bookmark
				deletedColors.add(bookmark.color)

		# Update local state first so UI (verse icons + modal list) updates instantly
		for verse in pks
			let existing = bookmarks.find(do |bookmark| return bookmark.verse == verse)
			if existing
				bookmarks.splice(bookmarks.indexOf(existing), 1)
		bookmarks = bookmarks.slice()
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		if bookmarks.length !== 0
			for color in deletedColors when !bookmarks.find(do |bookmark| return bookmark.color == color)
				user.deleteBookmarkFromUserMap translation, book, chapter, color
		window.dispatchEvent(new CustomEvent('bookmarks-updated'))
		imba.commit!
		activities.cleanUp!

		# Sync to API/vault in background (like add: UI first, then persist)
		requestDeleteBookmark(pks)

	def nextVerseHasTheSameBookmark verse_index
		let current_bookmark = getBookmark(verses[verse_index].pk)
		if current_bookmark
			const next_verse = verses[verse_index + 1]
			if next_verse
				let next_bookmark = getBookmark(next_verse.pk)
				if next_bookmark
					if next_bookmark.collection == current_bookmark.collection and next_bookmark.note == current_bookmark.note
						return yes
		return no

	def clearPenSketchesForCurrentChapter
		activities.clearPenSketchesFor(translation, book, chapter)

export default GenericReader