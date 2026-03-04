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
		return {
			verse: item.verse
			date: item.date or 0
			color: item.color or ''
			collection: item.collection or item.collections or ''
			note: item.note or ''
		}

	def buildGroupedBookmarks items
		let grouped = []
		let currentKey = ''
		let current = null
		for item in items
			const verse = item.verse
			if !verse
				continue
			const key = "{item.date}:{verse.translation}:{verse.book}:{verse.chapter}"
			if key != currentKey
				currentKey = key
				current = {
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
				}
				grouped.push(current)
			else
				current.verses.push(verse.verse)
				current.pks.push(verse.pk)
				current.text.push(verse.text)
				current.title = titleRow(current.translation, current.book, current.chapter, current.verses)
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

	# Extract the actual highlighted text for a freehand range (single or multi-verse), then wrap as "...snippet..."
	def getFreehandHighlightSnippet r, h
		if !r or !r.verses or !r.verses.length
			return '...'
		const startVerse = h.startVerse != null ? h.startVerse : h.endVerse
		const endVerse = h.endVerse != null ? h.endVerse : startVerse
		const startOffset = Math.max(0, h.startOffset != null ? h.startOffset : 0)
		const endOffset = h.endOffset != null ? h.endOffset : 0
		let snippet = ''
		if startVerse == endVerse
			const verseObj = r.verses.find(do |v| return v.verse == startVerse)
			const text = verseObj and verseObj.text ? verseObj.text : ''
			const end = Math.min(text.length, endOffset)
			snippet = text.slice(startOffset, end).trim()
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
		if !snippet
			return '...'
		return '...' + snippet + '...'

	# Convert reader freehand highlights to same shape as verse highlight entries (so they appear in the list and filters)
	def readerFreehandToHighlightEntries r
		let entries = []
		if !r or !r.freehandHighlights or !r.freehandHighlights.length or !r.verses or !r.verses.length
			return entries
		const defaultColor = '#eab308'
		for h in r.freehandHighlights
			const color = (h.color and String(h.color).trim()) or defaultColor
			const startVerse = h.startVerse != null ? h.startVerse : h.endVerse
			const text = getFreehandHighlightSnippet(r, h)
			entries.push({
				date: 0
				color: color
				translation: r.translation
				book: r.book
				chapter: r.chapter
				verse: startVerse
				text: text
				_freehandKey: "f:{r.translation}:{r.book}:{r.chapter}:{h.startVerse}:{h.startOffset}:{h.endVerse}:{h.endOffset}"
			})
		return entries

	def loadBookmarks
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] loadBookmarks: start')
		loading = yes
		error = ''
		let token = fetchToken + 1
		fetchToken = token
		try
			let data = []
			if window.navigator.onLine and user.username
				const pageSize = 200
				let rangeFrom = 0
				let keepLoading = yes
				while keepLoading
					let batch = await API.getJson("/get-profile-bookmarks/{rangeFrom}/{rangeFrom + pageSize}/")
					if token != fetchToken
						return
					if typeof console != 'undefined' and console.log
						console.log('[HIGHLIGHTS] loadBookmarks: batch from API', { rangeFrom, count: batch.length })
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

			# Merge current reader(s) highlights so list updates in real time
			let existingPks = new Set()
			for item in data
				if item.verse and item.verse.pk != null
					existingPks.add(item.verse.pk)
			let mergedFromReader = 0
			for r in [reader, parallelReader]
				const fromReader = readerBookmarksToApiShape(r)
				if typeof console != 'undefined' and console.log
					console.log('[HIGHLIGHTS] loadBookmarks: merge check', { readerName: r.me or 'parallel', readerBookmarksLength: (r.bookmarks and r.bookmarks.length) or 0, readerVersesLength: (r.verses and r.verses.length) or 0, fromReaderCount: fromReader.length })
				for item in fromReader
					if item.verse and item.verse.pk != null and !existingPks.has(item.verse.pk)
						data.push(item)
						existingPks.add(item.verse.pk)
						mergedFromReader += 1
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] loadBookmarks: after merge', { dataLength: data.length, mergedFromReader })

			let normalized = []
			for item in data
				const normalizedItem = normalizeBookmark(item)
				if normalizedItem
					normalized.push(normalizedItem)

			normalized = normalized.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			# Bookmarks tab: only entries with no color (bookmark-only). Highlights must not appear here.
			let bookmarkOnlyNormalized = normalized.filter(do |item| return !item.color or String(item.color).trim() == '')
			groupedBookmarks = buildGroupedBookmarks(bookmarkOnlyNormalized)
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
				console.log('[HIGHLIGHTS] loadBookmarks: done', { highlightEntriesLength: listLen, verses: highlightEntries.map(do |e| return e.chapter + ':' + (e.verse != null ? String(e.verse) : '?') ) })
				console.log('[HIGHLIGHTS DEBUG] Counter = filteredHighlights.length =', listLen, '(when filter=all). List items =', listLen, '. Match:', true)
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
			return {
				type: 'book'
				date: entry.date or 0
				translation: translation
				book: book
				name: entry.name or getBookName(translation, book)
			}
		)

	# Reactive: verse bookmarks from current reader(s), bookmark-only (no color). Same logic as highlights — so list and counter update immediately.
	@computed get readerVerseBookmarksForList
		let data = []
		for r in [reader, parallelReader]
			for item in readerBookmarksToApiShape(r)
				if item.verse and item.verse.pk != null
					const color = item.color and String(item.color).trim()
					if !color
						data.push(item)
		let normalized = []
		for item in data
			const n = normalizeBookmark(item)
			if n
				normalized.push(n)
		if !normalized.length
			return []
		normalized = normalized.sort(do |a, b| return (b.date or 0) - (a.date or 0))
		return buildGroupedBookmarks(normalized)

	# Merge loaded groupedBookmarks with reactive reader bookmarks (reader wins for same verse so list is immediate)
	@computed get effectiveGroupedBookmarks
		const fromReader = readerVerseBookmarksForList
		const fromLoad = groupedBookmarks
		const seenPks = new Set()
		let merged = []
		for entry in fromReader
			for pk in (entry.pks or [])
				seenPks.add(pk)
			merged.push(entry)
		for entry in fromLoad
			const pks = entry.pks or []
			const already = pks.some(do |pk| return seenPks.has(pk))
			unless already
				for pk in pks
					seenPks.add(pk)
				merged.push(entry)
		return merged.sort(do |a, b| return (b.date or 0) - (a.date or 0))

	@computed get combinedBookmarks
		let combined = bookBookmarkEntries.concat(effectiveGroupedBookmarks)
		return combined.sort(do |a, b| return (b.date or 0) - (a.date or 0))

	@computed get filteredBookmarks
		if bookmarkFilter == 'book'
			return combinedBookmarks.filter(do |e| return e.type == 'book')
		if bookmarkFilter == 'verse'
			return combinedBookmarks.filter(do |e| return e.type == 'verse')
		return combinedBookmarks

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
	def getDisplayHighlights
		const base = if highlightEntries.length > 0 then highlightEntries else _cachedHighlightEntries
		if highlightFilter == 'all'
			return base
		return base.filter(do |entry| return entry.color == highlightFilter)

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
				const defaultColor = '#eab308'
				const color = (item.color and String(item.color).trim()) or defaultColor
				fallback.push({ date: item.date or 0, color: color, translation: v.translation, book: v.book, chapter: v.chapter, verse: v.verse, text: v.text or '' })
			for entry in readerFreehandToHighlightEntries(r)
				fallback.push({ date: entry.date, color: entry.color, translation: entry.translation, book: entry.book, chapter: entry.chapter, verse: entry.verse, text: entry.text or '' })
		if fallback.length > 0
			highlightEntries = fallback.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			_cachedHighlightEntries = highlightEntries
			window.dispatchEvent(new CustomEvent('highlights-cache-updated'))
			if typeof console != 'undefined' and console.log
				console.log('[HIGHLIGHTS] ensureHighlightsFromReader: set highlightEntries.length=', highlightEntries.length)
			imba.commit!

	# Sync verse bookmarks from reader into modal state immediately (so counter and list update without refresh)
	def mergeReaderBookmarksIntoState
		let data = []
		for r in [reader, parallelReader]
			for item in readerBookmarksToApiShape(r)
				if item.verse and item.verse.pk != null
					data.push(item)
		let normalized = []
		for item in data
			const normalizedItem = normalizeBookmark(item)
			if normalizedItem
				normalized.push(normalizedItem)
		if normalized.length
			normalized = normalized.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			# Bookmarks tab: only bookmark-only (no color). Highlights must not appear here.
			let bookmarkOnlyNormalized = normalized.filter(do |item| return !item.color or String(item.color).trim() == '')
			groupedBookmarks = buildGroupedBookmarks(bookmarkOnlyNormalized)
			# Highlights tab: only entries with color. Bookmark-only must not appear here.
			let highlights = []
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
			highlightEntries = highlights.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			_cachedHighlightEntries = highlightEntries
		imba.commit!

	def handleBookmarksUpdated
		if typeof console != 'undefined' and console.log
			console.log('[HIGHLIGHTS] bookmarks-updated received, syncing and refetching')
		mergeReaderBookmarksIntoState!
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
		# Show reader bookmarks immediately so counter and list are correct before API fetch completes
		mergeReaderBookmarksIntoState!
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
			<button.toggle-btn .active=(activeTab == 'bookmarks') @click=(activeTab = 'bookmarks')>
				<svg src=BookmarkIcon aria-hidden=yes>
				"Bookmarks"
				<span.toggle-count> combinedBookmarks.length
			<button.toggle-btn .active=(activeTab == 'highlights') @click=(activeTab = 'highlights')>
				<svg src=Highlighter aria-hidden=yes>
				"Highlights"
				<span.toggle-count> getDisplayHighlights().length

		<div.bookmarks-content>
			if activeTab == 'bookmarks'
				if combinedBookmarks.length
					<div.bookmark-filter>
						<button.filter-btn .active=(bookmarkFilter == 'recent') @click=(bookmarkFilter = 'recent') title="Recent">
							<svg src=Clock aria-hidden=yes>
							"Recent"
						<button.filter-btn .active=(bookmarkFilter == 'book') @click=(bookmarkFilter = 'book') title="Books only">
							<svg src=BookOpen aria-hidden=yes>
							"Book"
						<button.filter-btn .active=(bookmarkFilter == 'verse') @click=(bookmarkFilter = 'verse') title="Verse bookmarks only">
							<svg src=BookmarkIcon aria-hidden=yes>
							"Verse"
						<button.filter-btn .active=(bookmarkFilter == 'all') @click=(bookmarkFilter = 'all') title="All bookmarks">
							<svg src=List aria-hidden=yes>
							"All"
				if loading
					<p.bookmarks-empty> "Loading bookmarks..."
				elif error
					<p.bookmarks-empty> error
				elif !filteredBookmarks.length
					<p.bookmarks-empty> "No bookmarks yet"
				else
					<div.bookmarks-list>
						for entry in filteredBookmarks
							<button.bookmark-item @click=openBookmark(entry)>
								<div.bookmark-icon>
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
			else
				if activeTab == 'highlights'
					ensureHighlightsFromReader!
				if getDisplayHighlights().length > 0
					<div.highlight-filter>
						<button .active=(highlightFilter == 'all') @click=(highlightFilter = 'all')> "All"
						for color in getDisplayHighlightColors()
							<button .active=(highlightFilter == color) @click=(highlightFilter = color) title=color>
								<span.color-swatch [bgc:{color}]>
				if loading
					<p.bookmarks-empty> "Loading highlights..."
				elif !getDisplayHighlights().length
					<p.bookmarks-empty> "No highlights yet"
				else
					<div.bookmarks-list>
						for entry in getDisplayHighlights()
							<button.bookmark-item @click=openVerseBookmark(entry)>
								<div.bookmark-icon>
									<span.color-swatch [bgc:{entry.color or '#eab308'}]>
								<div.bookmark-text>
									<div.bookmark-title> "{getBookName(entry.translation, entry.book)} {entry.chapter}:{entry.verse}"
									<div.bookmark-meta> entry.translation
									<div.bookmark-snippet innerHTML=(entry.text or '')>

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
