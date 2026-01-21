import { getValue, setValue } from '../utils'

import ALL_BOOKS from '../data/translations_books.json'

import API from './Api'
import theme from './Theme'
import settings from './Settings'
import activities from './Activities'
import user from './User'
import vault from './Vault'
import notifications from './Notifications'

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
		# else
		let highlight = bookmarks.find(do |element| return element.verse == pk)
		if highlight
			return  "linear-gradient({highlight.color} 0px, {highlight.color} 100%)"
		else
			return ''
	
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
		if !activities.copySelectMode or activities.copySelectStartPK == 0
			# Hide selection box
			let box = document.querySelector('.verse-selection-box')
			if box
				box.style.display = 'none'
			return
		
		let startIdx = verses.findIndex(do |v| return v.pk == activities.copySelectStartPK)
		let endIdx = verses.findIndex(do |v| return v.pk == activities.copySelectEndPK)
		if startIdx == -1 or endIdx == -1
			let box = document.querySelector('.verse-selection-box')
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
				let box = document.querySelector('.verse-selection-box')
				if !box
					return
				
				# Get the article container
				let articleEl = document.querySelector('article')
				if !articleEl
					box.style.display = 'none'
					return
				
				# Find verse elements by traversing the article's children
				# Verse elements contain a span with id="{versePrefix}{verse.verse}"
				let firstVerseEl = null
				let lastVerseEl = null
				
				# Get all verse text elements (they have IDs matching verse numbers)
				for i in [minIdx .. maxIdx]
					if verses[i]
						let verseNum = verses[i].verse
						# Try to find by verse number (with or without prefix)
						let verseEl = document.getElementById(String(verseNum))
						# If not found, try with 'p' prefix (for parallel readers)
						if !verseEl
							verseEl = document.getElementById("p{verseNum}")
						# If still not found, search within article
						if !verseEl and articleEl
							let allSpans = articleEl.querySelectorAll('span[id]')
							for span in allSpans
								if span.id == String(verseNum) or span.id == "p{verseNum}" or span.id.endsWith(String(verseNum))
									verseEl = span
									break
						
						if verseEl
							if !firstVerseEl
								firstVerseEl = verseEl
							lastVerseEl = verseEl
				
				if !firstVerseEl or !lastVerseEl
					box.style.display = 'none'
					return
				
				# Calculate position relative to article
				# Use offsetTop relative to article
				let articleRect = articleEl.getBoundingClientRect()
				let firstRect = firstVerseEl.getBoundingClientRect()
				let lastRect = lastVerseEl.getBoundingClientRect()
				
				# Calculate top and height relative to article
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
		if !document.getSelection().isCollapsed or activities.activeModal
			return

		if activities.copySelectMode
			# Single selection - clicking a new verse replaces the previous selection
			activities.copySelectStartPK = pk
			activities.copySelectEndPK = pk
			activities.copySelectedVersesPKs = [pk]
			self.updateCopySelectRange!
			imba.commit!
			return

		if activities.selectedParallel != undefined and activities.selectedParallel != me
			return

		activities.selectedParallel = me
		unless activities.highlight_color
			activities.highlight_color = activities.randomColor

		if activities.selectedVersesPKs.length == 0 && me == 'main'
			window.history.pushState(
				{},
				'',
				window.location.origin + '/' + translation + '/' + book + '/' + chapter + '/' + id + '/'
			)

		# Check if the user chosen a verse in the same parallel scope
		if activities.selectedVersesPKs.includes(pk)
			activities.selectedVersesPKs.splice(activities.selectedVersesPKs.indexOf(pk), 1)
			activities.selectedVerses.splice(activities.selectedVerses.indexOf(id), 1)
			let collection = getCollectionOfChosen(pk)
			if collection
				for piece in collection.split(' | ')
					if piece != ''
						activities.selectedCategories.splice(activities.selectedCategories.indexOf(piece), 1)
		else
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
			activities.activeVerseAction ||= 'options'
		else
			activities.activeVerseAction = undefined
			activities.selectedParallel = undefined


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

		for verse in activities.selectedVersesPKs
			if bookmarks.find(do |bookmark| return bookmark.verse == verse)
				bookmarks.splice(bookmarks.indexOf(bookmarks.find(do |bookmark| return bookmark.verse == verse)), 1)
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