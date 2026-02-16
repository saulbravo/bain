import { getValue, setValue } from '../utils'

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

class GenericReader
	@observable translation\string
	@observable book\number
	@observable chapter\number
	verses\Array<Verse> = []
	loading\boolean = no
	@observable bookmarks\Bookmark[] = []
	@observable freehandHighlights = []
	show_verse_picker\boolean = no
	verse\number|string = 0

	me = '' # constant to indicate the main reader versus the parallel reader

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

	@action def prevChapter
		freehandHighlights = []
		if chapter - 1 > 0
			chapter -= 1
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index - 1]
				book = books[current_index - 1].bookid
				chapter = books[current_index - 1].chapters

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

	@action def prevBook
		freehandHighlights = []
		let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
		if books[current_index - 1]
			book = books[current_index - 1].bookid
			chapter = 1

	def getBookmark verseNumber\number
		if user.username
			return bookmarks.find(do |element| return element.verse == verseNumber)

	def getHighlight pk\number
		# Don't return background for selected verses - they use text color instead
		# if activities.selectedVersesPKs.length && activities.selectedVersesPKs.includes(pk)
		# 	return "linear-gradient(var(--acc-hover) 0px, var(--acc-hover) 100%)"
		let highlight = bookmarks.find(do |element| return element.verse == pk)
		if highlight
			return  "linear-gradient({highlight.color} 0px, {highlight.color} 100%)"
		else
			return ''
	
	def getHighlightTextColor pk\number
		let highlight = bookmarks.find(do |element| return element.verse == pk)
		if !highlight
			return null
			
		let color = highlight.color
		# Map common CSS names to contrast colors
		const darkPresets = ['FireBrick', 'RebeccaPurple', 'RoyalBlue', 'OliveDrab', 'Chocolate']
		if darkPresets.includes(color)
			return 'white'
		
		if color.startsWith('#')
			let hex = color.replace('#', '')
			if hex.length == 3
				hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2]
			
			try
				const r = parseInt(hex.slice(0, 2), 16)
				const g = parseInt(hex.slice(2, 4), 16)
				const b = parseInt(hex.slice(4, 6), 16)
				const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
				return luminance > 0.5 ? 'black' : 'white'
			catch
				return 'black'
		
		return 'black'
	
	def applyHighlightPreview pks\number[], color\string
		# Immediately apply highlight to verses without saving to server
		# This creates a preview that will be saved when user clicks save
		if !color or color == ''
			return
		
		if !pks or pks.length == 0
			return
		
		for pk in pks
			# Remove existing bookmark for this verse (if any)
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == pk)
			if existingBookmark
				bookmarks.splice(bookmarks.indexOf(existingBookmark), 1)
			
			# Add new preview bookmark
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

		if vault.available
			offline_bookmarks = await vault.getChapterBookmarks(verses.map(do |verse| return verse.pk))

		bookmarks = offline_bookmarks.concat(server_bookmarks)
		if activities and activities.cacheChapterState
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
		imba.commit!

	def getFreehandHighlights
		if !user.username or !window.navigator.onLine
			return

		try
			freehandHighlights = await API.getJson("/get-freehand-highlights/" + translation + '/' + book + '/' + chapter + '/', 'freehandHighlights')
			if activities and activities.cacheChapterState
				activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
			imba.commit!
		catch error
			console.log "Error fetching freehand highlights:", error

	def saveFreehandHighlights
		if !user.username or !window.navigator.onLine
			return

		try
			await API.post("/save-freehand-highlights/", {
				translation: translation,
				book: book,
				chapter: chapter,
				highlights: freehandHighlights
			})
		catch error
			console.log "Error saving freehand highlights:", error

	def clearAllChapterHighlights
		# Clear freehand highlights
		freehandHighlights = []
		saveFreehandHighlights!
		
		# Clear regular highlights
		if user.username
			let pks = bookmarks.map(do |b| b.verse)
			if pks.length > 0
				const deletedColors = new Set<string>()
				for b in bookmarks
					if b.color
						deletedColors.add(b.color)
					
				requestDeleteBookmark(pks)
				bookmarks = []
				
				for color in deletedColors
					user.deleteBookmarkFromUserMap translation, book, chapter, color
		
		activities.cleanUp!
		imba.commit!

	@computed get selectionHasBookmark
		for verse in activities.selectedVersesPKs
			if bookmarks.find(do |element| return element.verse == verse)
				return yes
		return no

	def getCollectionOfChosen verseNumber\number
		let highlight = bookmarks.find(do |element| return element.verse == verseNumber)
		if highlight
			return highlight.collection
		else ''

	def pushCollectionIfExist pk\number
		for piece in getCollectionOfChosen(pk).split(' | ')
			if piece != '' && !activities.selectedCategories.includes(piece)
				activities.selectedCategories.push(piece)


	def selectVerse pk\number, id\number
		if !document.getSelection().isCollapsed or activities.activeModal or activities.freehandHighlightMode
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
		if boundingRect.bottom + activities.bottomDrawerOffset > window.innerHeight - 124 # 124 is the relative height of the bottom drawer
			verseElement.scrollIntoView({behavior: theme.scrollBehavior, block: 'center'})

		if activities.selectedVersesPKs.length
			showDeleteBookmark()
			mergeNotes()
			# Show slideup unless it was explicitly suppressed (from modal navigation)
			# We use a special marker 'suppressed' to indicate suppression
			if activities.activeVerseAction != 'suppressed'
				# Always set to 'options' for normal selections (not from modal)
				activities.activeVerseAction = 'options'
				activities.isVerseActionsMinimized = no
				console.log('[DEBUG] Showing verse-actions slideup')
			else
				console.log('[DEBUG] Verse selected but slideup suppressed (from modal navigation)')
		else
			console.log('[DEBUG] Verse deselected, hiding slideup')
			# Reset to empty string so next selection will show slideup
			activities.activeVerseAction = ''
			activities.selectedParallel = undefined
		
		imba.commit!


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

	def saveBookmark
		unless user.username
			window.location.pathname = "/signup/"
			return

		if activities.note == '<br>'
			activities.note = ''

		let collections = activities.selectedCategories.map(do(str) str.trim!).join(' | ')

		let bookmarkToSave = {
			verses: activities.selectedVersesPKs,
			color: activities.highlight_color,
			date: Date.now(),
			collections: collections
			note: activities.note
		}

		def saveOffline
			if vault.available
				vault.saveBookmarksToStorageUntilOnline(bookmarkToSave)

		if window.navigator.onLine
			try
				await API.post("/save-bookmarks/", bookmarkToSave)
				notifications.push('saved')
			catch e
				notifications.push('error')
				saveOffline!
		else saveOffline!

		for verse in activities.selectedVersesPKs
			# Remove existing bookmark (including preview ones)
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == verse)
			if existingBookmark
				bookmarks.splice(bookmarks.indexOf(existingBookmark), 1)
			
			# Add saved bookmark (will be persisted to server/storage)
			bookmarks.push({
				verse: verse,
				date: Date.now(),
				color: activities.highlight_color,
				collection: collections
				note: activities.note
			})
		user.saveUserBookmarkToMap translation, book, chapter, activities.highlight_color
		# add to user.categories the new collections
		for category in activities.selectedCategories
			if !user.categories.includes(category)
				user.categories.push(category)
		activities.cleanUp!

	def requestDeleteBookmark pks\number[]
		vault.deleteBookmarks(pks)
		if window.navigator.onLine
			try
				await API.post("/delete-bookmarks/", { verses: pks })
				notifications.push('deleted')
			catch err
				deleteLater (pks)
		else deleteLater (pks)

	def deleteLater pks\number[]
		let bookmarksToDelete = getValue('bookmarks-to-delete')
		setValue('bookmarks-to-delete', bookmarksToDelete.concat(pks))

	def deleteBookmark pks\number[]
		if !user.username
			window.location.pathname = "/signup/"
			return

		const deletedColors = new Set<string>()
		for verse in activities.selectedVersesPKs
			let bookmark = bookmarks.find(do |element| return element.verse == verse)
			if bookmark
				deletedColors.add(bookmark.color)

		requestDeleteBookmark(pks)
		for verse in activities.selectedVersesPKs
			if bookmarks.find(do |bookmark| return bookmark.verse == verse)
				bookmarks.splice(bookmarks.indexOf(bookmarks.find(do |bookmark| return bookmark.verse == verse)), 1)

		if bookmarks.length !== 0
			for color in deletedColors when !bookmarks.find(do |bookmark| return bookmark.color == color)
				user.deleteBookmarkFromUserMap translation, book, chapter, color
		activities.cleanUp!

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

export default GenericReader