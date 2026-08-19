import { getValue, setValue } from '../utils'

import API from './Api'
import activities from './Activities'
import { translationNames } from '../constants'
import vault from './Vault'
import settings from './Settings'
import parallelReader from './ParallelReader'
import readingHistory from './ReadingHistory'
import notifications from './Notifications'

import GenericReader from './GenericReader'


class Reader < GenericReader
	@observable translation\string
	@observable book\number
	@observable chapter\number

	me = 'main'

	@autorun def saveTranslation
		if translationNames[translation]
			setValue('translation', translation)

	@autorun def saveBook
		setValue('book', book)

	@autorun def saveChapter
		setValue('chapter', chapter)

	def constructor
		super()
		if window.translation
			unless 'international' in window.location.pathname
				translation = window.translation
				book = window.book
				chapter = window.chapter
				verse = window.verse
			verses = window.verses
			loading = no
		else
			const segments = window.location.pathname.split('/').filter(Boolean)
			const hasExplicitRoute = segments[0] == 'international' ? segments.length >= 4 : segments.length >= 3
			translation = getValue('translation') || 'NVI'
			if hasExplicitRoute
				book = getValue('book') || 1
				chapter = getValue('chapter') || 1
			else
				book = 1
				chapter = 1

	get myRenderer
		document.getElementById('main-reader')

	@action def updateParallelReader book, chapter
		if settings.parallel_sync && parallelReader.enabled && parallelReader.theChapterExistInThisTranslation(book, chapter)
			unless parallelReader.book == book and parallelReader.chapter == chapter
				parallelReader.verse = undefined
			parallelReader.book = book
			parallelReader.chapter = chapter

	# Whenever translation, book or chapter changes, we need to fetch the verses for the current chapter.
	@autorun
	def fetchVerses
		syncMainTabState!
		console.log("Fetching verses for {translation} {book}:{chapter}")
		unless ensureValidChapterForTranslation!
			return
		let requestId = (self._fetchId or 0) + 1
		self._fetchId = requestId
		const reqTranslation = translation
		const reqBook = book
		const reqChapter = chapter
		const reqVerse = verse
		
		document.title = nameOfCurrentBook + ' ' + chapter + ' ' + translationNames[translation] + " Bolls Bible"
		const cached = activities and activities.getCachedChapter ? activities.getCachedChapter(translation, book, chapter) : null
		const keepExisting = activities and activities.isSwitchingTab
		if cached
			verses = cached.verses
			bookmarks = cached.bookmarks
			freehandHighlights = cached.freehandHighlights
		loading = yes
		unless cached or keepExisting
			verses = []
		imba.commit!

		updateParallelReader book, chapter

		try
			if vault.downloaded_translations.indexOf(translation) != -1
				let fetched = await vault.getChapter(translation, book, chapter)
				if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
					return
				verses = fetched
			else
				let fetched = await API.getJson("/get-chapter/{translation}/{book}/{chapter}/")
				if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
					return
				verses = Array.isArray(fetched) ? fetched : []
		catch error
			console.error(error)
			notifications.push('error')
		finally
			# Only finalize if this request is still current
			if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
				return
			activities.cacheChapterState(translation, book, chapter, verses, bookmarks, freehandHighlights)
			loading = no
			unless reqVerse
				if activities.activeModal == 'books'
					activities.cleanUp { preserveBooksModal: yes }
				else
					activities.cleanUp!

		if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
			return
		readingHistory.saveToHistory(translation, book, chapter, reqVerse)
		getBookmarks!
		getFreehandHighlights!

		if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
			return
		if reqVerse
			if typeof reqVerse === 'string' and reqVerse.includes('-')
				const parts = reqVerse.split('-')
				findVerse(parts[0], parts[1], yes)
			else
				goToAndSelectVerse(reqVerse)
			verse = undefined
		else
			show_verse_picker = yes
			if myRenderer
				myRenderer.scrollTop = 0

		# if the pathname has one of 4 `/` in it then call the pushState
		const pathnameSlices = window.location.pathname.split('/').filter(Boolean).length
		if (pathnameSlices == 0 or pathnameSlices > 2) and activities.selectedVersesPKs.length == 0 and not verse
			const newLocation = window.location.origin + '/' + translation + '/' + book + '/' + chapter + '/'
			if window.location.href != newLocation
				window.history.pushState({
						translation: translation,
						book: book,
						chapter: chapter,
					},
					'',
					window.location.origin + '/' + translation + '/' + book + '/' + chapter + '/'
				)

	@action def randomVerse
		try
			let randomVerse
			// check if the translation is available offline and make offline request
			if vault.downloaded_translations.indexOf(translation) != -1
				const response = await window.fetch("/sw/get-random-verse/{translation}/")
				randomVerse = await response.json()
			else
				if window.navigator.onLine
					randomVerse = await API.getJson("/get-random-verse/{translation}/")
			if randomVerse
				const targetBook = randomVerse.book
				const targetChapter = randomVerse.chapter
				const targetVerse = randomVerse.verse
				if book == targetBook and chapter == targetChapter
					goToAndSelectVerse(targetVerse, randomVerse.pk)
				else
					book = targetBook
					chapter = targetChapter
					verse = targetVerse
		catch error
			console.error error
			notifications.push('error')


const reader = new Reader()

export default reader