import API from '../lib/Api'
import activities from '../lib/Activities'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import vault from '../lib/Vault'
import user from '../lib/User'
import { getBookName } from '../utils'

import BookmarkIcon from 'lucide-static/icons/bookmark.svg'
import BookOpen from 'lucide-static/icons/book-open.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import Clock from 'lucide-static/icons/clock.svg'
import List from 'lucide-static/icons/list.svg'
import * as ICONS from 'imba-phosphor-icons'

# Shared cache so highlights persist when parent re-renders and creates a new modal instance
let _cachedHighlightEntries = []
const BOOKMARK_MARKER = '__bolls_bookmark__'
const TEST_PAGE_SIZE = 10

tag bookmarks-modal
	loading = yes
	error = ''
	highlightFilter = 'all'
	groupedBookmarks = []
	highlightEntries = []
	fetchToken = 0
	# 'bookmarks' | 'highlights' - which list is shown
	activeTab = 'bookmarks'
	# 'recent' | 'book' | 'verse' | 'all' - bookmark list filter
	bookmarkFilter = 'recent'
	bookmarkVisibleCount = TEST_PAGE_SIZE
	highlightVisibleCount = TEST_PAGE_SIZE
	_bookmarksUpdatedHandler = null
	_highlightsCacheClearHandler = null
	_highlightsCacheUpdatedHandler = null
	cacheVersion = 0

	def titleRow translation\string, book\number, chapter\number, verses\number[]
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

	def normalizeBookmark item
		if !item or !item.verse
			return null
		const rawColor = item.color or ''
		const rawCollection = item.collection or item.collections or ''
		const rawNote = item.note or ''
		const hasColor = String(rawColor).trim() != ''
		const hasMarker = String(rawCollection).split(' | ').includes(BOOKMARK_MARKER)
		const cleanCollection = String(rawCollection)
			.split(' | ')
			.map(do |piece| return piece.trim!)
			.filter(do |piece| return piece != '' and piece != BOOKMARK_MARKER)
			.join(' | ')
		const hasBookmarkMetadata = String(cleanCollection).trim() != '' or String(rawNote).trim() != ''
		return {
			verse: item.verse
			date: item.date or 0
			color: rawColor
			collection: cleanCollection
			note: rawNote
			# Bookmarks tab should exclude highlight-only rows.
			# Treat as bookmark if: explicit marker, legacy no-color row, or has bookmark metadata.
			isBookmarked: hasMarker or !hasColor or hasBookmarkMetadata
		}

	def buildGroupedBookmarks items
		let grouped = []
		for item in items
			const verse = item.verse
			if !verse
				continue
			grouped.push({
				type: 'verse'
				date: item.date or 0
				color: item.color or ''
				collection: item.collection or ''
				note: item.note or ''
				translation: verse.translation
				book: verse.book
				chapter: verse.chapter
				verses: [verse.verse]
				pks: [verse.pk]
				text: [verse.text]
				title: titleRow(verse.translation, verse.book, verse.chapter, [verse.verse])
			})
		return grouped

	def readerBookmarksToApiShape r
		let items = []
		if !r or !r.verses or !r.bookmarks
			return items
		for b in r.bookmarks
			const v = r.verses.find(do |verse| return verse.pk == b.verse)
			if v
				items.push({
					verse: { pk: v.pk, translation: r.translation, book: r.book, chapter: r.chapter, verse: v.verse, text: v.text or '' }
					date: b.date
					color: b.color
					collection: b.collection or ''
					note: b.note or ''
				})
		return items

	def getVerseText r, verseNumber\number
		const verseObj = r.verses.find(do |v| return v.verse == verseNumber)
		return verseObj and verseObj.text ? verseObj.text : ''

	# Extract freehand snippet and add ellipses only when selection starts/ends mid-verse.
	def getFreehandHighlightSnippetData r, h
		if !r or !r.verses or !r.verses.length
			return { text: '', ellipsisStart: yes, ellipsisEnd: yes }
		const startVerse = h.startVerse != null ? h.startVerse : h.endVerse
		const endVerse = h.endVerse != null ? h.endVerse : startVerse
		const startOffset = Math.max(0, h.startOffset != null ? h.startOffset : 0)
		const endOffset = h.endOffset != null ? h.endOffset : 0
		let snippet = ''
		let ellipsisStart = no
		let ellipsisEnd = no
		if startVerse == endVerse
			const text = getVerseText(r, startVerse)
			const end = Math.min(text.length, endOffset)
			snippet = text.slice(startOffset, end).trim()
			ellipsisStart = startOffset > 0
			ellipsisEnd = end < text.length
		else
			# Span multiple verses: start verse from startOffset, full middle verses, end verse to endOffset
			const versesSorted = r.verses.slice().sort(do |a, b| return a.verse - b.verse)
			for v in versesSorted
				if v.verse < startVerse or v.verse > endVerse
					continue
				const t = v.text or ''
				if v.verse == startVerse
					snippet += t.slice(startOffset)
				elif v.verse == endVerse
					snippet += t.slice(0, Math.min(t.length, endOffset))
				else
					snippet += t
			snippet = snippet.trim()
			ellipsisStart = startOffset > 0
			const endText = getVerseText(r, endVerse)
			ellipsisEnd = Math.min(endText.length, endOffset) < endText.length
		if !snippet
			return { text: '...', ellipsisStart: yes, ellipsisEnd: yes }
		const rendered = (ellipsisStart ? '...' : '') + snippet + (ellipsisEnd ? '...' : '')
		return { text: rendered, ellipsisStart, ellipsisEnd }

	# Convert reader freehand highlights to same shape as verse highlight entries (so they appear in the list and filters)
	def readerFreehandToHighlightEntries r
		let entries = []
		if !r or !r.freehandHighlights or !r.freehandHighlights.length or !r.verses or !r.verses.length
			return entries
		for h in r.freehandHighlights
			if !h
				continue
			const color = (h.color and String(h.color).trim()) or '#eab308'
			let startVerse = h.startVerse != null ? h.startVerse : h.endVerse
			let endVerse = h.endVerse != null ? h.endVerse : startVerse
			let startOffset = Math.max(0, h.startOffset != null ? h.startOffset : 0)
			let endOffset = Math.max(0, h.endOffset != null ? h.endOffset : 0)
			if startVerse > endVerse
				const tmpVerse = startVerse
				startVerse = endVerse
				endVerse = tmpVerse
				const tmpOffset = startOffset
				startOffset = endOffset
				endOffset = tmpOffset
			const textData = getFreehandHighlightSnippetData(r, {
				startVerse: startVerse
				startOffset: startOffset
				endVerse: endVerse
				endOffset: endOffset
			})
			entries.push({
				date: 0
				color: color
				translation: r.translation
				book: r.book
				chapter: r.chapter
				verse: startVerse
				endVerse: endVerse
				startOffset: startOffset
				endOffset: endOffset
				text: textData.text
				_freehandKey: "f:{r.translation}:{r.book}:{r.chapter}:{startVerse}:{startOffset}:{endVerse}:{endOffset}:{color}"
			})
		return entries

	def loadBookmarks
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] loadBookmarks: start', { online: window.navigator.onLine, username: user.username })
		loading = yes
		error = ''
		let token = fetchToken + 1
		fetchToken = token
		try
			let data = []
			if window.navigator.onLine
				const pageSize = 200
				let rangeFrom = 0
				let keepLoading = yes
				while keepLoading
					let batch = await API.getJson("/get-profile-bookmarks/{rangeFrom}/{rangeFrom + pageSize}/")
					if token != fetchToken
						return
					unless Array.isArray(batch)
						if batch and Array.isArray(batch.bookmarks)
							batch = batch.bookmarks
						elif batch and Array.isArray(batch.results)
							batch = batch.results
						else
						if typeof console != 'undefined' and console.warn
								console.warn('[HIGHLIGHTS] loadBookmarks: non-array profile response, stopping pagination', { rangeFrom, batch })
							break
					if typeof console != 'undefined' and console.log
						let sample = batch.length > 0 ? batch[0] : null
						console.log('[HIGHLIGHTS] loadBookmarks: batch from API', {
							rangeFrom,
							count: batch.length,
							sampleHasVerse: sample and sample.verse ? yes : no,
							sampleVersePk: sample and sample.verse ? sample.verse.pk : null,
							sampleTranslation: sample and sample.verse ? sample.verse.translation : null
						})
					data = data.concat(batch)
					if batch.length < pageSize
						keepLoading = no
					else
						rangeFrom += pageSize
			elif vault.available
				data = await vault.getBookmarks()
			else
				data = []
			if token != fetchToken
				return
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] loadBookmarks: raw data total', {
					count: data.length,
					withVerse: data.filter(do |i| return i and i.verse).length
				})

			let normalized = []
			let dropped = 0
			for item in data
				const normalizedItem = normalizeBookmark(item)
				if normalizedItem
					normalized.push(normalizedItem)
				else
					dropped += 1

			normalized = normalized.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] loadBookmarks: normalized', {
					count: normalized.length,
					dropped,
					sample: normalized.slice(0, 5).map(do |n| return n and n.verse ? "{n.verse.translation} {n.verse.book}:{n.verse.chapter}:{n.verse.verse}" : 'invalid')
				})
			# Bookmarks tab: only explicit bookmarks (exclude highlight-only rows).
			groupedBookmarks = buildGroupedBookmarks(normalized.filter(do |item| return item.isBookmarked))
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] groupedBookmarks count =', groupedBookmarks.length)
				console.log('[HIGHLIGHTS] groupedBookmarks sample =', groupedBookmarks.slice(0, 5).map(do |g| return g.title).join(' | '))
			# Highlights tab: only entries with a color. Bookmark-only entries must not appear here.
			let highlights = []
			const defaultHighlightColor = '#eab308'
			for item in normalized
				const v = item.verse
				if !v or v.verse == null
					continue
				const color = item.color and String(item.color).trim()
				if !color
					continue
				highlights.push({
					date: item.date or 0
					color: color
					translation: v.translation
					book: v.book
					chapter: v.chapter
					verse: v.verse
					text: v.text or ''
				})
			# Merge freehand highlights from current reader(s) so they appear in list and color filters
			let freehandKeys = new Set()
			for r in [reader, parallelReader]
				for entry in readerFreehandToHighlightEntries(r)
					if entry._freehandKey and !freehandKeys.has(entry._freehandKey)
						freehandKeys.add(entry._freehandKey)
						highlights.push({
							date: entry.date
							color: entry.color
							translation: entry.translation
							book: entry.book
							chapter: entry.chapter
							verse: entry.verse
							endVerse: entry.endVerse
							startOffset: entry.startOffset
							endOffset: entry.endOffset
							text: entry.text or ''
						})
			highlightEntries = highlights.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			_cachedHighlightEntries = highlightEntries
			window.dispatchEvent(new CustomEvent('highlights-cache-updated'))
			# Fallback: if we have 0 but reader has highlights (e.g. modal reopened before API had them), sync from reader
			const readerHasVerse = reader.bookmarks and reader.bookmarks.length > 0 and reader.verses and reader.verses.length > 0
			const readerHasFreehand = (reader.freehandHighlights and reader.freehandHighlights.length > 0) or (parallelReader.freehandHighlights and parallelReader.freehandHighlights.length > 0)
			if highlightEntries.length === 0 and (readerHasVerse or readerHasFreehand)
				if typeof console != 'undefined' and console.log
					console.log('[HIGHLIGHTS] loadBookmarks: fallback merge from reader (verse=', readerHasVerse, ', freehand=', readerHasFreehand, ')')
				let fallbackHighlights = []
				for r in [reader, parallelReader]
					for item in readerBookmarksToApiShape(r)
						const v = item.verse
						if !v or v.verse == null
							continue
						const color = item.color and String(item.color).trim()
						if !color
							continue
						fallbackHighlights.push({
							date: item.date or 0
							color: color
							translation: v.translation
							book: v.book
							chapter: v.chapter
							verse: v.verse
							text: v.text or ''
						})
					for entry in readerFreehandToHighlightEntries(r)
						fallbackHighlights.push({
							date: entry.date
							color: entry.color
							translation: entry.translation
							book: entry.book
							chapter: entry.chapter
							verse: entry.verse
							endVerse: entry.endVerse
							startOffset: entry.startOffset
							endOffset: entry.endOffset
							text: entry.text or ''
						})
				if fallbackHighlights.length > 0
					highlightEntries = fallbackHighlights.sort(do |a, b| return (b.date or 0) - (a.date or 0))
					_cachedHighlightEntries = highlightEntries
					window.dispatchEvent(new CustomEvent('highlights-cache-updated'))
					if typeof console != 'undefined' and console.log
						console.log('[HIGHLIGHTS] loadBookmarks: fallback set highlightEntries.length=', highlightEntries.length)
			if highlightFilter != 'all' and highlightEntries.length and !highlightEntries.some(do |e| return (e.color or '') == highlightFilter)
				highlightFilter = 'all'
			if typeof console != 'undefined' and console.log
				const listLen = highlightEntries.length
				console.log('[HIGHLIGHTS] loadBookmarks done; highlights count =', listLen)
				console.log('[HIGHLIGHTS] combined count =', combinedBookmarksList().length, '; filtered count =', getFilteredBookmarks().length, '; tab =', activeTab, '; filter =', bookmarkFilter)
		catch err
			console.error(err)
			if token != fetchToken
				return
			error = 'Unable to load bookmarks'
			groupedBookmarks = []
			highlightEntries = []
			_cachedHighlightEntries = []
		finally
			if token != fetchToken
				return
			loading = no
			imba.commit!

	@computed get bookBookmarkEntries
		return activities.bookBookmarks.map(do |entry|
			const translation = entry.translation
			const book = entry.book
			const chapter = entry.chapter or 1
			return {
				type: 'book'
				date: entry.date or 0
				translation: translation
				book: book
				chapter: chapter
				name: "{entry.name or getBookName(translation, book)} {chapter}"
			}
		)

	def combinedBookmarksList
		let combined = bookBookmarkEntries.concat(groupedBookmarks)
		return combined.sort(do |a, b| return (b.date or 0) - (a.date or 0))

	def getFilteredBookmarks
		const combined = combinedBookmarksList()
		# Book filter: only book-level bookmarks (e.g. bookmarked chapter in top-left), not verses
		if bookmarkFilter == 'book'
			return combined.filter(do |e| return e and e.type == 'book')
		# Verse filter: only verse-level bookmarks, not book/chapter entries
		if bookmarkFilter == 'verse'
			return combined.filter(do |e| return e and e.type == 'verse')
		# Recent / All: show everything (book + verse), sorted by date
		return combined

	def setBookmarkFilter filter\string
		bookmarkFilter = filter
		bookmarkVisibleCount = TEST_PAGE_SIZE
		imba.commit!

	# Use cache when this instance has no highlights (e.g. parent re-created modal); cacheVersion forces re-read when cache updates
	@computed get effectiveHighlightEntries
		const _ = cacheVersion
		if highlightEntries.length > 0
			return highlightEntries
		if _cachedHighlightEntries.length > 0
			return _cachedHighlightEntries
		return highlightEntries

	@computed get highlightColors
		const colors = new Set()
		for entry in effectiveHighlightEntries
			if entry.color
				colors.add(entry.color)
		return Array.from(colors)

	@computed get filteredHighlights
		const base = effectiveHighlightEntries
		if highlightFilter == 'all'
			return base
		return base.filter(do |entry| return entry.color == highlightFilter)

	# Display list for Highlights pane: use instance state or fall back to module cache so UI is correct when computed lags
	def groupContinuousHighlights entries
		let buckets = {}
		for entry in entries
			if !entry or entry.verse == null
				continue
			const key = "{entry.translation}:{entry.book}:{entry.chapter}:{entry.color or ''}"
			unless buckets[key]
				buckets[key] = []
			buckets[key].push(entry)
		let grouped = []
		for own key, items of buckets
			const sorted = items.slice().sort(do |a, b|
				const aStartVerse = a.verse or 0
				const bStartVerse = b.verse or 0
				if aStartVerse != bStartVerse
					return aStartVerse - bStartVerse
				const aStartOffset = a.startOffset != null ? a.startOffset : 0
				const bStartOffset = b.startOffset != null ? b.startOffset : 0
				return aStartOffset - bStartOffset
			)
			let run = null
			for item in sorted
				const startVerse = item.verse
				const endVerse = item.endVerse != null ? item.endVerse : startVerse
				const startOffset = item.startOffset != null ? item.startOffset : 0
				const endOffset = item.endOffset != null ? item.endOffset : 999999
				if run == null
					run = {
						date: item.date or 0
						color: item.color
						translation: item.translation
						book: item.book
						chapter: item.chapter
						verse: startVerse
						startOffset: startOffset
						endVerse: endVerse
						endOffset: endOffset
						_texts: [item.text or '']
					}
				else
					let canMerge = no
					if startVerse < run.endVerse
						canMerge = yes
					elif startVerse == run.endVerse and startOffset <= (run.endOffset + 1)
						canMerge = yes
					elif startVerse == (run.endVerse + 1) and run.endOffset >= 999999 and startOffset <= 0
						canMerge = yes
					if canMerge
						if endVerse > run.endVerse or (endVerse == run.endVerse and endOffset > run.endOffset)
							run.endVerse = endVerse
							run.endOffset = endOffset
					else
						grouped.push({
							date: run.date
							color: run.color
							translation: run.translation
							book: run.book
							chapter: run.chapter
							verse: run.verse
							startOffset: run.startOffset
							endVerse: run.endVerse
							endOffset: run.endOffset
							text: run._texts.join(' ')
						})
						run = {
							date: item.date or 0
							color: item.color
							translation: item.translation
							book: item.book
							chapter: item.chapter
							verse: startVerse
							startOffset: startOffset
							endVerse: endVerse
							endOffset: endOffset
							_texts: [item.text or '']
						}
					run.date = Math.max(run.date or 0, item.date or 0)
					if item.text and !run._texts.includes(item.text)
						run._texts.push(item.text)
			if run != null
				grouped.push({
					date: run.date
					color: run.color
					translation: run.translation
					book: run.book
					chapter: run.chapter
					verse: run.verse
					startOffset: run.startOffset
					endVerse: run.endVerse
					endOffset: run.endOffset
					text: run._texts.join(' ')
				})
		return grouped.sort(do |a, b| return (b.date or 0) - (a.date or 0))

	def getDisplayHighlights
		const base = if highlightEntries.length > 0 then highlightEntries else _cachedHighlightEntries
		const filtered = if highlightFilter == 'all' then base else base.filter(do |entry| return entry.color == highlightFilter)
		return groupContinuousHighlights(filtered)

	def visibleBookmarks
		return getFilteredBookmarks().slice(0, bookmarkVisibleCount)

	def canLoadMoreBookmarks
		return getFilteredBookmarks().length > bookmarkVisibleCount

	def loadMoreBookmarks
		bookmarkVisibleCount += TEST_PAGE_SIZE
		imba.commit!

	def visibleHighlights
		return getDisplayHighlights().slice(0, highlightVisibleCount)

	def canLoadMoreHighlights
		return getDisplayHighlights().length > highlightVisibleCount

	def loadMoreHighlights
		highlightVisibleCount += TEST_PAGE_SIZE
		imba.commit!

	def switchToBookmarksTab
		activeTab = 'bookmarks'
		bookmarkVisibleCount = TEST_PAGE_SIZE
		imba.commit!

	def switchToHighlightsTab
		activeTab = 'highlights'
		highlightVisibleCount = TEST_PAGE_SIZE
		imba.commit!

	def setHighlightFilter filter\string
		highlightFilter = filter
		highlightVisibleCount = TEST_PAGE_SIZE
		imba.commit!

	def highlightTitle entry
		let versesPart = String(entry.verse)
		if entry.endVerse and entry.endVerse != entry.verse
			versesPart = "{entry.verse}-{entry.endVerse}"
		return "{getBookName(entry.translation, entry.book)} {entry.chapter}:{versesPart}"

	# Unique colors present in current highlights (including custom colors) — only show filters for colors that exist
	def getDisplayHighlightColors
		const list = getDisplayHighlights()
		const colors = new Set()
		for entry in list
			if entry.color and String(entry.color).trim()
				colors.add(entry.color)
		return Array.from(colors)

	def openBookBookmark entry
		const translation = entry.translation
		const book = entry.book
		const chapter = entry.chapter or 1
		activities.tabUpdateTargetIndex = activities.activeTabIndex
		activities.applyTabToReader({
			translation: translation
			book: book
			chapter: chapter
		}, 'bookmarks-modal:book')
		activities.cleanUp { onPopState: yes }

	def openVerseBookmark entry
		const translation = entry.translation
		const book = entry.book
		const chapter = entry.chapter
		const verse = entry.verse or (entry.verses and entry.verses[0])
		activities.tabUpdateTargetIndex = activities.activeTabIndex
		activities.applyTabToReader({
			translation: translation
			book: book
			chapter: chapter
		}, 'bookmarks-modal:verse')
		if verse != undefined and verse != null
			reader.verse = verse
		activities.cleanUp { onPopState: yes }
		if verse != undefined and verse != null
			setTimeout(&, 400) do
				reader.findVerse(String(verse))

	def openBookmark entry
		if entry.type == 'book'
			return openBookBookmark(entry)
		openVerseBookmark(entry)

	def ensureHighlightsFromReader
		if highlightEntries.length > 0 or loading
			return
		const hasVerse = reader.bookmarks and reader.bookmarks.length > 0 and reader.verses and reader.verses.length > 0
		const hasFreehand = (reader.freehandHighlights and reader.freehandHighlights.length > 0) or (parallelReader.freehandHighlights and parallelReader.freehandHighlights.length > 0)
		if !hasVerse and !hasFreehand
			return
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] ensureHighlightsFromReader: syncing from reader (verse=', hasVerse, ', freehand=', hasFreehand, ')')
		let fallback = []
		for r in [reader, parallelReader]
			for item in readerBookmarksToApiShape(r)
				const v = item.verse
				if !v or v.verse == null
					continue
				# Only add entries that have a color (real highlights). Bookmark-only must not appear in Highlights.
				const color = item.color and String(item.color).trim()
				if !color
					continue
				fallback.push({ date: item.date or 0, color: color, translation: v.translation, book: v.book, chapter: v.chapter, verse: v.verse, text: v.text or '' })
			for entry in readerFreehandToHighlightEntries(r)
				fallback.push({
					date: entry.date
					color: entry.color
					translation: entry.translation
					book: entry.book
					chapter: entry.chapter
					verse: entry.verse
					endVerse: entry.endVerse
					startOffset: entry.startOffset
					endOffset: entry.endOffset
					text: entry.text or ''
				})
		if fallback.length > 0
			highlightEntries = fallback.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			_cachedHighlightEntries = highlightEntries
			window.dispatchEvent(new CustomEvent('highlights-cache-updated'))
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] ensureHighlightsFromReader: set highlightEntries.length=', highlightEntries.length)
			imba.commit!

	def handleBookmarksUpdated
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] bookmarks-updated received, reloading from profile DB')
		loadBookmarks!

	def handleHighlightsCacheClear
		_cachedHighlightEntries = []
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] highlights-cache-clear received, cache cleared')

	def handleHighlightsCacheUpdated
		cacheVersion = Date.now()
		imba.commit!

	def mount
		# Restore from cache so new instance shows last known highlights (parent may re-create modal on re-render)
		if _cachedHighlightEntries.length > 0
			highlightEntries = _cachedHighlightEntries.slice()
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] mount: restored highlightEntries from cache, length=', highlightEntries.length)
		# DB-driven list only: clear local list and always fetch full profile bookmarks.
		groupedBookmarks = []
		bookmarkVisibleCount = TEST_PAGE_SIZE
		highlightVisibleCount = TEST_PAGE_SIZE
		loadBookmarks!
		# One delayed refresh helps when auth/session initializes shortly after mount.
		setTimeout(&, 500) do
			loadBookmarks!
		_bookmarksUpdatedHandler = do
			handleBookmarksUpdated!
		window.addEventListener('bookmarks-updated', _bookmarksUpdatedHandler)
		_highlightsCacheClearHandler = do
			handleHighlightsCacheClear!
		window.addEventListener('highlights-cache-clear', _highlightsCacheClearHandler)
		_highlightsCacheUpdatedHandler = do
			handleHighlightsCacheUpdated!
		window.addEventListener('highlights-cache-updated', _highlightsCacheUpdatedHandler)

	def unmount
		if _bookmarksUpdatedHandler
			window.removeEventListener('bookmarks-updated', _bookmarksUpdatedHandler)
			_bookmarksUpdatedHandler = null
		if _highlightsCacheClearHandler
			window.removeEventListener('highlights-cache-clear', _highlightsCacheClearHandler)
			_highlightsCacheClearHandler = null
		if _highlightsCacheUpdatedHandler
			window.removeEventListener('highlights-cache-updated', _highlightsCacheUpdatedHandler)
			_highlightsCacheUpdatedHandler = null

	<self.bookmarks-modal-root>
		<header.header-with-close>
			<button.close-btn @click=activities.cleanUp title=t.close>
				<svg src=ICONS.X aria-hidden=yes>
			<h2.header-title> "Highlights and Bookmarks"
			<span.header-spacer>

		<div.toggle-row>
			<button.toggle-btn .active=(activeTab == 'bookmarks') @click=switchToBookmarksTab>
				<svg src=BookmarkIcon aria-hidden=yes>
				"Bookmarks"
				<span.toggle-count> combinedBookmarksList().length
			<button.toggle-btn .active=(activeTab == 'highlights') @click=switchToHighlightsTab>
				<svg src=Highlighter aria-hidden=yes>
				"Highlights"
				<span.toggle-count> getDisplayHighlights().length

		<div.bookmarks-content>
			if activeTab == 'bookmarks'
				if combinedBookmarksList().length
					<div.bookmark-filter>
						<button.filter-btn .active=(bookmarkFilter == 'recent') @click=setBookmarkFilter('recent') title="Recent">
							<svg src=Clock aria-hidden=yes>
							"Recent"
						<button.filter-btn .active=(bookmarkFilter == 'book') @click=setBookmarkFilter('book') title="Books only">
							<svg src=BookOpen aria-hidden=yes>
							"Book"
						<button.filter-btn .active=(bookmarkFilter == 'verse') @click=setBookmarkFilter('verse') title="Verse bookmarks only">
							<svg src=BookmarkIcon aria-hidden=yes>
							"Verse"
						<button.filter-btn .active=(bookmarkFilter == 'all') @click=setBookmarkFilter('all') title="All bookmarks">
							<svg src=List aria-hidden=yes>
							"All"
				if loading
					<p.bookmarks-empty> "Loading bookmarks..."
				elif error
					<p.bookmarks-empty> error
				elif !getFilteredBookmarks().length
					<p.bookmarks-empty> "No bookmarks yet"
				else
					<div.bookmarks-list[key={(bookmarkFilter + ':' + getFilteredBookmarks().length)}]>
						for entry in visibleBookmarks()
							<button.bookmark-item .is-book=(entry.type == 'book') .is-verse=(entry.type == 'verse') @click=openBookmark(entry)>
								<div.bookmark-icon.bookmark-icon-bookmarks>
									if entry.type == 'book'
										<svg src=BookOpen aria-hidden=yes>
									else
										<svg src=BookmarkIcon aria-hidden=yes>
								<div.bookmark-text>
									<div.bookmark-title>
										if entry.type == 'book'
											entry.name
										else
											entry.title
									<div.bookmark-meta>
										if entry.type == 'book'
											entry.translation
										else
											entry.translation
									<div.bookmark-date>
										if entry.date
											new Date(entry.date).toLocaleString()
					if canLoadMoreBookmarks()
						<button.load-more-btn @click=loadMoreBookmarks> "Load More"
			else
				if activeTab == 'highlights'
					ensureHighlightsFromReader!
				if getDisplayHighlights().length > 0
					<div.highlight-filter>
						<button .active=(highlightFilter == 'all') @click=setHighlightFilter('all')> "All"
						for color in getDisplayHighlightColors()
							<button .active=(highlightFilter == color) @click=setHighlightFilter(color) title=color>
								<span.color-swatch [bgc:{color}]>
				if loading
					<p.bookmarks-empty> "Loading highlights..."
				elif !getDisplayHighlights().length
					<p.bookmarks-empty> "No highlights yet"
				else
					<div.bookmarks-list>
						for entry in visibleHighlights()
							<button.bookmark-item @click=openVerseBookmark(entry)>
								<div.bookmark-icon>
									<span.color-swatch [bgc:{entry.color or '#eab308'}]>
								<div.bookmark-text>
									<div.bookmark-title> highlightTitle(entry)
									<div.bookmark-meta> entry.translation
									<div.bookmark-snippet innerHTML=(entry.text or '')>
					if canLoadMoreHighlights()
						<button.load-more-btn @click=loadMoreHighlights> "Load More"

	css
		.bookmarks-modal-root
			d:flex
			fld:column
			min-height:0
			h:100%
			max-height:100%

		header
			mb:0.5rem

		.header-with-close
			d:grid
			grid-template-columns: 2rem 1fr 2rem
			ai:center
			g:0.5rem

		.close-btn
			bgc:transparent
			c:inherit
			min-width:2rem
			w:2rem
			cursor:pointer
			d:flex
			fls:0
			grid-column:1

		.header-title
			text-align:center
			margin:0
			-webkit-line-clamp:2
			overflow:hidden
			display:-webkit-box
			-webkit-box-orient:vertical
			fs:1.1em
			grid-column:2
			justify-self:center

		.header-spacer
			grid-column:3
			w:2rem
			fls:0

		.bookmark-filter
			d:flex
			g:0.5rem
			flw:wrap
			mb:0.5rem

		.filter-btn
			d:flex
			ai:center
			g:0.35rem
			bgc:$acc-bgc
			c:inherit
			rd:999px
			p:0.25rem 0.6rem
			fs:0.8rem
			cursor:pointer
			bd:1px solid transparent

		.filter-btn@hover
			bgc:$acc-bgc-hover

		.filter-btn.active
			bgc:$acc-bgc-hover
			c:$acc-hover
			bd-color:$acc-hover

		.filter-btn svg
			size:1rem
			fls:0

		.toggle-row
			d:flex
			g:0.5rem
			mb:1rem
			w:100%

		.toggle-btn
			d:flex
			ai:center
			g:0.5rem
			flex:1
			p:0.6rem 1rem
			rd:0.5rem
			bgc:$acc-bgc
			c:inherit
			bd:1px solid $acc-bgc-hover
			cursor:pointer
			fs:0.95rem

		.toggle-btn@hover
			bgc:$acc-bgc-hover

		.toggle-btn.active
			bgc:$acc-bgc-hover
			c:$acc-hover
			bd-color:$acc-hover

		.toggle-btn svg
			size:1.2rem
			fls:0

		.toggle-count
			fs:0.8rem
			o:0.7
			ml:auto

		.bookmarks-content
			d:flex
			fld:column
			min-height:0
			flex:1
			w:100%
			bgc:$bgc
			bd:1px solid $acc-bgc-hover
			rd:0.75rem
			p:0.75rem
			overflow:hidden

		.bookmarks-list
			d:flex
			fld:column
			g:0.5rem
			overflow-y:auto
			min-height:0
			flex:1
			-webkit-overflow-scrolling:touch

		.bookmark-item
			d:flex
			ai:flex-start
			g:0.5rem
			p:0.5rem
			rd:0.5rem
			ta:left
			bgc:transparent
			c:inherit
			cursor:pointer
			b:1px solid transparent

		.bookmark-item@hover
			bgc:$acc-bgc-hover
			b:1px solid $acc-bgc

		.bookmark-icon
			d:flex
			ai:center
			jc:center
			size:1.75rem
			flex-shrink:0

		.bookmark-icon-bookmarks
			# Bookmarks list: always show bookmark icon (not color swatch) so bookmarks are not confused with highlights
			svg
				fill: currentColor
				stroke: none

		.bookmark-text
			d:flex
			fld:column
			g:0.15rem
			min-width:0
			flex:1

		.bookmark-title
			fs:0.95rem
			fw:600
			ws:nowrap
			of:hidden
			text-overflow:ellipsis

		.bookmark-meta
			fs:0.75rem
			o:0.65

		.bookmark-date
			fs:0.7rem
			o:0.5

		.bookmark-snippet
			fs:0.8rem
			o:0.7
			display:-webkit-box
			-webkit-line-clamp:2
			-webkit-box-orient:vertical
			overflow:hidden

		.bookmarks-empty
			ta:center
			o:0.6
			p:1rem 0

		.load-more-btn
			mt:0.5rem
			align-self:center
			bgc:$acc-bgc
			c:inherit
			font:inherit
			fw:400
			p:0.4rem 0.9rem
			rd:0.5rem
			cursor:pointer
			bd:1px solid $acc-bgc-hover

		.load-more-btn@hover
			bgc:$acc-bgc-hover

		.highlight-filter
			d:flex
			g:0.5rem
			flw:wrap
			mb:0.5rem

			button
				bgc:$acc-bgc
				c:inherit
				rd:999px
				p:0.2rem 0.6rem
				fs:0.75rem
				cursor:pointer

			button.active
				bgc:$acc-bgc-hover
				c:$acc-hover

		.color-swatch
			d:inline-block
			size:0.9rem
			rd:50%
			bd:1px solid $acc-bgc-hover
			flex-shrink:0
