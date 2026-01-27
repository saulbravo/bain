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
	show_verse_picker\boolean = no
	verse\number|string = 0

	me = '' # constant to indicate the main reader versus the parallel reader

	@computed get books
		unless ALL_BOOKS[translation]
			console.log "Translation {translation} not found in ALL_BOOKS, defaulting to YLT"
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
		if chapter + 1 <= chaptersOfCurrentBook
			chapter += 1
		else
			let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
			if books[current_index + 1]
				book = books[current_index + 1].bookid
				chapter = 1

	@action def prevChapter
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
		let current_index = books.indexOf(books.find(do |element| return element.bookid == book))
		if books[current_index + 1]
			book = books[current_index + 1].bookid
			chapter = 1

	@action def prevBook
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
			console.log('[getHighlight] Found highlight for pk', pk, 'color:', highlight.color)
			return  "linear-gradient({highlight.color} 0px, {highlight.color} 100%)"
		else
			return ''
	
	def applyHighlightPreview pks\number[], color\string
		# Immediately apply highlight to verses without saving to server
		# This creates a preview that will be saved when user clicks save
		console.log('[applyHighlightPreview] Called with pks:', pks, 'color:', color)
		if !color or color == ''
			console.warn('[applyHighlightPreview] No color provided, skipping')
			return
		
		if !pks or pks.length == 0
			console.warn('[applyHighlightPreview] No verses provided, skipping')
			return
		
		for pk in pks
			# Remove existing bookmark for this verse (if any)
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == pk)
			if existingBookmark
				console.log('[applyHighlightPreview] Removing existing bookmark for pk', pk)
				bookmarks.splice(bookmarks.indexOf(existingBookmark), 1)
			
			# Add new preview bookmark
			console.log('[applyHighlightPreview] Adding preview bookmark for pk', pk, 'with color', color)
			bookmarks.push({
				verse: pk,
				date: Date.now(),
				color: color,
				collection: '',
				note: ''
			})
		
		console.log('[applyHighlightPreview] Updated bookmarks array, new length:', bookmarks.length)
		imba.commit!
	
	def getArticleElement
		# Get the article element for this specific reader
		# Use the me property to identify which reader (me.me is 'main' or 'parallel')
		# me is the instance, and me.me is the property value
		let readerType = self.me or ''
		console.log('[getArticleElement v3] Called - me instance:', me, 'me.me property:', self.me, 'readerType:', readerType)
		
		let readerId = readerType == 'main' ? 'main-reader' : 'parallel-reader'
		console.log('[getArticleElement v3] Looking for readerId:', readerId)
		
		let readerEl = document.getElementById(readerId)
		if readerEl
			let article = readerEl.querySelector('article')
			console.log('[getArticleElement v2] Article found for', readerId, ':', !!article)
			return article
		console.warn('[getArticleElement v2] Reader element not found:', readerId, 'Available elements:', document.getElementById('main-reader'), document.getElementById('parallel-reader'))
		return null
	
	def getSelectionBox
		# Get the selection box for this specific reader's article
		let readerType = self.me or ''
		console.log('[getSelectionBox v3] Called for reader:', me, 'readerType:', readerType)
		let articleEl = self.getArticleElement()
		if !articleEl
			console.warn('[getSelectionBox v2] Article element not found')
			return null
		let box = articleEl.querySelector('.verse-selection-box')
		console.log('[getSelectionBox v2] Selection box found:', !!box, 'in article:', !!articleEl)
		if !box
			console.warn('[getSelectionBox v2] Box not found! Checking all boxes in document:', document.querySelectorAll('.verse-selection-box').length)
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
		console.log('[updateCopySelectRange v4] Called for reader:', me, 'readerType:', readerType)
		
		# Get per-reader PKs
		let startPK = readerType == 'main' ? activities.copySelectStartPKMain : activities.copySelectStartPKParallel
		let endPK = readerType == 'main' ? activities.copySelectEndPKMain : activities.copySelectEndPKParallel
		
		console.log('[updateCopySelectRange v4] copySelectMode:', activities.copySelectMode, 'startPK:', startPK, 'endPK:', endPK, 'readerType:', readerType)
		console.log('[updateCopySelectRange v4] Main PKs:', activities.copySelectStartPKMain, '-', activities.copySelectEndPKMain)
		console.log('[updateCopySelectRange v4] Parallel PKs:', activities.copySelectStartPKParallel, '-', activities.copySelectEndPKParallel)
		
		# Only update if this reader has copy-select active
		if !activities.copySelectMode or startPK == 0
			console.log('[updateCopySelectRange v4] Copy-select not active or no start PK for this reader')
			let box = self.getSelectionBox()
			if box
				box.style.display = 'none'
			return
		
		let startIdx = verses.findIndex(do |v| return v.pk == startPK)
		let endIdx = verses.findIndex(do |v| return v.pk == endPK)
		console.log('[updateCopySelectRange v4] startIdx:', startIdx, 'endIdx:', endIdx, 'startPK:', startPK, 'endPK:', endPK)
		
		if startIdx == -1 or endIdx == -1
			console.warn('[updateCopySelectRange] Verse indices not found')
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
					console.warn('[updateCopySelectRange] Selection box not found')
					return
				
				# Get the article container for this reader
				let articleEl = self.getArticleElement()
				if !articleEl
					console.warn('[updateCopySelectRange] Article element not found')
					box.style.display = 'none'
					return
				
				# Determine verse prefix based on reader
				let readerType = self.me or ''
				let versePrefix = readerType == 'main' ? '' : 'p'
				console.log('[updateCopySelectRange v3] Using verse prefix:', versePrefix, 'readerType:', readerType)
				
				# Find verse elements
				let firstVerseEl = null
				let lastVerseEl = null
				
				for i in [minIdx .. maxIdx]
					if verses[i]
						let verseNum = verses[i].verse
						let verseId = versePrefix ? versePrefix + String(verseNum) : String(verseNum)
						console.log('[updateCopySelectRange] Looking for verse ID:', verseId)
						
						# Try getElementById first
						let verseEl = document.getElementById(verseId)
						# Verify it's within this article
						if verseEl and articleEl.contains(verseEl)
							console.log('[updateCopySelectRange] Found verse element:', verseId)
							if !firstVerseEl
								firstVerseEl = verseEl
							lastVerseEl = verseEl
						else
							# Try querySelector within article
							verseEl = articleEl.querySelector('span[id="{verseId}"]')
							if verseEl
								console.log('[updateCopySelectRange] Found verse via querySelector:', verseId)
								if !firstVerseEl
									firstVerseEl = verseEl
								lastVerseEl = verseEl
							else
								console.warn('[updateCopySelectRange] Verse element not found:', verseId)
				
				if !firstVerseEl or !lastVerseEl
					console.warn('[updateCopySelectRange] Verse elements not found, hiding box')
					box.style.display = 'none'
					return
				
				# Calculate position relative to article
				let top = firstVerseEl.offsetTop - 4
				let bottom = lastVerseEl.offsetTop + lastVerseEl.offsetHeight + 4
				
				console.log('[updateCopySelectRange] Positioning box - top:', top, 'height:', (bottom - top))
				
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
				console.warn error

		if vault.available
			offline_bookmarks = await vault.getChapterBookmarks(verses.map(do |verse| return verse.pk))

		bookmarks = offline_bookmarks.concat(server_bookmarks)
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
		console.log('[selectVerse] Called with pk:', pk, 'id:', id)
		console.log('[selectVerse] Current selectedVersesPKs:', activities.selectedVersesPKs)
		console.log('[selectVerse] Selection collapsed:', document.getSelection().isCollapsed)
		console.log('[selectVerse] Active modal:', activities.activeModal)
		
		if !document.getSelection().isCollapsed or activities.activeModal
			console.log('[selectVerse] Early return - selection not collapsed or modal active')
			return

		if activities.copySelectMode
			let readerType = self.me or ''
			console.log('[selectVerse v4] Copy select mode active, me:', me, 'readerType:', readerType)
			# Switch copy-select to this reader and set the verse
			activities.copySelectModeReader = me
			# Set per-reader PKs for parallel view support
			if readerType == 'main'
				activities.copySelectStartPKMain = pk
				activities.copySelectEndPKMain = pk
				console.log('[selectVerse v4] Set main reader PKs - start:', pk, 'end:', pk)
			else
				activities.copySelectStartPKParallel = pk
				activities.copySelectEndPKParallel = pk
				console.log('[selectVerse v4] Set parallel reader PKs - start:', pk, 'end:', pk)
			# Also set global PKs for backward compatibility
			activities.copySelectStartPK = pk
			activities.copySelectEndPK = pk
			activities.copySelectedVersesPKs = [pk]
			console.log('[selectVerse v4] Set copySelectModeReader to:', me, 'pk:', pk)
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
				console.log('[selectVerse v6] Switching to different reader, clearing previous selection')
				# Clear previous selection to allow switching sides
				activities.selectedVersesPKs = []
				activities.selectedVerses = []
				activities.selectedCategories = []
				activities.selectedParallel = undefined
				activities.activeVerseAction = undefined

		activities.selectedParallel = me
		unless activities.highlight_color
			activities.highlight_color = activities.randomColor
			console.log('[selectVerse] Generated random color:', activities.highlight_color)

		if activities.selectedVersesPKs.length == 0 && me == 'main'
			window.history.pushState(
				{},
				'',
				window.location.origin + '/' + translation + '/' + book + '/' + chapter + '/' + id + '/'
			)

		# Check if the user chosen a verse in the same parallel scope
		if activities.selectedVersesPKs.includes(pk)
			console.log('[selectVerse] Deselecting verse pk:', pk)
			activities.selectedVersesPKs.splice(activities.selectedVersesPKs.indexOf(pk), 1)
			activities.selectedVerses.splice(activities.selectedVerses.indexOf(id), 1)
			let collection = getCollectionOfChosen(pk)
			if collection
				for piece in collection.split(' | ')
					if piece != ''
						activities.selectedCategories.splice(activities.selectedCategories.indexOf(piece), 1)
		else
			console.log('[selectVerse] Selecting verse pk:', pk)
			activities.selectedVersesPKs.push(pk)
			activities.selectedVerses.push(id)
			pushCollectionIfExist(pk)
		
		console.log('[selectVerse] After selection, selectedVersesPKs:', activities.selectedVersesPKs)

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

		console.log('[selectVerse] Final check - selectedVersesPKs.length:', activities.selectedVersesPKs.length)
		if activities.selectedVersesPKs.length
			console.log('[selectVerse] Showing delete bookmark and setting activeVerseAction')
			showDeleteBookmark()
			mergeNotes()
			activities.activeVerseAction ||= 'options'
			console.log('[selectVerse] activeVerseAction set to:', activities.activeVerseAction)
		else
			console.log('[selectVerse] No verses selected, clearing activeVerseAction')
			activities.activeVerseAction = undefined
			activities.selectedParallel = undefined
		
		console.log('[selectVerse] Final state - selectedVersesPKs:', activities.selectedVersesPKs, 'activeVerseAction:', activities.activeVerseAction)
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
				console.error(e)
				notifications.push('error')
				saveOffline!
		else saveOffline!

		console.log('[saveBookmark] Saving bookmarks for verses:', activities.selectedVersesPKs)
		console.log('[saveBookmark] Color:', activities.highlight_color)
		console.log('[saveBookmark] Collections:', collections)
		console.log('[saveBookmark] Note:', activities.note)
		
		for verse in activities.selectedVersesPKs
			# Remove existing bookmark (including preview ones)
			let existingBookmark = bookmarks.find(do |bookmark| return bookmark.verse == verse)
			if existingBookmark
				console.log('[saveBookmark] Removing existing bookmark for verse', verse)
				bookmarks.splice(bookmarks.indexOf(existingBookmark), 1)
			
			# Add saved bookmark (will be persisted to server/storage)
			console.log('[saveBookmark] Adding saved bookmark for verse', verse)
			bookmarks.push({
				verse: verse,
				date: Date.now(),
				color: activities.highlight_color,
				collection: collections
				note: activities.note
			})
		
		console.log('[saveBookmark] Final bookmarks array length:', bookmarks.length)
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
				console.error err
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