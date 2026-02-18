import API from '../lib/Api'
import activities from '../lib/Activities'
import reader from '../lib/Reader'
import vault from '../lib/Vault'
import user from '../lib/User'
import { getBookName } from '../utils'

import BookmarkIcon from 'lucide-static/icons/bookmark.svg'
import BookOpen from 'lucide-static/icons/book-open.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import * as ICONS from 'imba-phosphor-icons'

tag bookmarks-modal
	loading = yes
	error = ''
	highlightFilter = 'all'
	groupedBookmarks = []
	highlightEntries = []
	fetchToken = 0

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

	def loadBookmarks
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

			let normalized = []
			for item in data
				const normalizedItem = normalizeBookmark(item)
				if normalizedItem
					normalized.push(normalizedItem)

			normalized = normalized.sort(do |a, b| return (b.date or 0) - (a.date or 0))
			groupedBookmarks = buildGroupedBookmarks(normalized)
			highlightEntries = normalized.map(do |item|
				return {
					date: item.date or 0
					color: item.color or ''
					translation: item.verse.translation
					book: item.verse.book
					chapter: item.verse.chapter
					verse: item.verse.verse
					text: item.verse.text
				}
			).filter(do |entry| return entry.color and entry.verse != undefined)
		catch err
			console.error(err)
			if token != fetchToken
				return
			error = 'Unable to load bookmarks'
			groupedBookmarks = []
			highlightEntries = []
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

	@computed get combinedBookmarks
		let combined = bookBookmarkEntries.concat(groupedBookmarks)
		return combined.sort(do |a, b| return (b.date or 0) - (a.date or 0))

	@computed get highlightColors
		const colors = new Set()
		for entry in highlightEntries
			if entry.color
				colors.add(entry.color)
		return Array.from(colors)

	@computed get filteredHighlights
		if highlightFilter == 'all'
			return highlightEntries
		return highlightEntries.filter(do |entry| return entry.color == highlightFilter)

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
		if verse
			reader.verse = verse
			setTimeout(&, 120) do
				reader.findVerse(String(verse))
		activities.cleanUp { onPopState: yes }

	def openBookmark entry
		if entry.type == 'book'
			return openBookBookmark(entry)
		openVerseBookmark({
			translation: entry.translation
			book: entry.book
			chapter: entry.chapter
			verse: entry.verses and entry.verses[0]
		})

	def mount
		loadBookmarks!

	<self>
		<header>
			<button @click=activities.cleanUp title=t.close>
				<svg src=ICONS.X aria-hidden=yes>
			<h2> "Bookmarks"
			<span.bookmarks-subtitle> "Bookmarks and Highlights"

		<div.bookmarks-layout>
			<section.bookmarks-column>
				<header>
					<div.bookmarks-column-title>
						<svg src=BookmarkIcon aria-hidden=yes>
						<h3> "Bookmarks"
					<span.bookmarks-count> combinedBookmarks.length
				if loading
					<p.bookmarks-empty> "Loading bookmarks..."
				elif error
					<p.bookmarks-empty> error
				elif !combinedBookmarks.length
					<p.bookmarks-empty> "No bookmarks yet"
				else
					<div.bookmarks-list>
						for entry in combinedBookmarks
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

			<section.bookmarks-column>
				<header>
					<div.bookmarks-column-title>
						<svg src=Highlighter aria-hidden=yes>
						<h3> "Highlights"
					<span.bookmarks-count> highlightEntries.length
				if highlightEntries.length
					<div.highlight-filter>
						<button .active=(highlightFilter == 'all') @click=(highlightFilter = 'all')> "All"
						for color in highlightColors
							<button .active=(highlightFilter == color) @click=(highlightFilter = color) title=color>
								<span.color-swatch [bgc:{color}]>
				if loading
					<p.bookmarks-empty> "Loading highlights..."
				elif !filteredHighlights.length
					<p.bookmarks-empty> "No highlights yet"
				else
					<div.bookmarks-list>
						for entry in filteredHighlights
							<button.bookmark-item @click=openVerseBookmark(entry)>
								<div.bookmark-icon>
									<span.color-swatch [bgc:{entry.color}]>
								<div.bookmark-text>
									<div.bookmark-title> "{getBookName(entry.translation, entry.book)} {entry.chapter}:{entry.verse}"
									<div.bookmark-meta> entry.translation
									<div.bookmark-snippet innerHTML=entry.text>

	css
		header
			d:hcc
			g:0.5rem
			mb:0.5rem

			button
				bgc:transparent
				c:inherit
				min-width:2rem
				w:2rem
				cursor:pointer
				d:flex
				fls:0

			h2
				text-align:center
				margin:auto
				-webkit-line-clamp:2
				overflow:hidden
				display:-webkit-box
				-webkit-box-orient:vertical
				fs:1.1em

		.bookmarks-subtitle
			fs:0.85em
			o:0.6
			ml:auto

		.bookmarks-layout
			d:flex
			g:1rem
			min-height:0
			@lt-sm
				fld:column

		.bookmarks-column
			d:flex
			fld:column
			fl:1
			min-height:0
			bgc:$bgc
			bd:1px solid $acc-bgc-hover
			rd:0.75rem
			p:0.75rem

		.bookmarks-column header
			d:flex
			ai:center
			jc:space-between
			mb:0.5rem

		.bookmarks-column-title
			d:flex
			ai:center
			g:0.5rem

			h3
				m:0
				fs:1rem

			svg
				size:1.25rem

		.bookmarks-count
			fs:0.8rem
			o:0.6

		.bookmarks-list
			d:flex
			fld:column
			g:0.5rem
			ofy:auto
			min-height:0
			flex:1

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
