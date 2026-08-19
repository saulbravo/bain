import { getValue, setValue } from '../utils/index.imba' 

import API from './Api'
import GenericReader from './GenericReader'
import activities from './Activities'
import readingHistory from './ReadingHistory'
import vault from './Vault'
import settings from './Settings'
import reader from './Reader'
import notifications from './Notifications'
import { translationNames } from '../constants'


class ParallelReader < GenericReader
	@observable translation\string = getValue('parallel_translation') || 'WLCa'
	@observable book\number = getValue('parallel_book') || 1
	@observable chapter\number = getValue('parallel_chapter') || 1
	@observable enabled\boolean = getValue('parallel_display') || false

	me = 'parallel'

	@autorun def saveTranslation
		if translationNames[translation]
			setValue('parallel_translation', translation)

	@autorun def saveBook
		setValue('parallel_book', book)

	@autorun def saveChapter
		setValue('parallel_chapter', chapter)

	@autorun def saveEnabled
		setValue('parallel_display', enabled)

	@action set enable value\boolean
		if value
			book = reader..book
			chapter = reader..chapter
		enabled = value

	get myRenderer
		document.getElementById('parallel-reader')

	@action def updateMainReader book, chapter
		# first check if that chapter and book exist in the main reader
		if reader.theChapterExistInThisTranslation(book, chapter)
			reader.book = book
			reader.chapter = chapter

	# Whenever translation, book or chapter changes, we need to fetch the verses for the current chapter.
	@autorun
	def fetchVerses
		unless ensureValidChapterForTranslation!
			return
		let requestId = (self._fetchId or 0) + 1
		self._fetchId = requestId
		const reqTranslation = translation
		const reqBook = book
		const reqChapter = chapter
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
			activities.cleanUp!

		if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
			return
		if settings.parallel_sync && enabled
			readingHistory.saveToHistory(translation, book, chapter, verse)
			updateMainReader book, chapter

		getBookmarks!
		getFreehandHighlights!

		if requestId != self._fetchId or translation != reqTranslation or book != reqBook or chapter != reqChapter
			return
		if verse
			if typeof verse === 'string' and verse.includes('-')
				const parts = verse.split('-')
				findVerse(parts[0], parts[1], yes)
			else
				goToAndSelectVerse(verse)
			verse = undefined
		else
			show_verse_picker = yes
			if myRenderer
				myRenderer.scrollTop = 0



const parallelReader = new ParallelReader()

export default parallelReader