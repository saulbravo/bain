import languages from '../data/languages.json'
import ALL_BOOKS from '../data/translations_books.json'

import Calendar from 'lucide-static/icons/calendar-1.svg'
import Download from 'lucide-static/icons/download.svg'
import Heart from 'lucide-static/icons/heart.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import ArrowLeft from 'lucide-static/icons/arrow-left.svg'
import BookOpen from 'lucide-static/icons/book-open.svg'
import Clock from 'lucide-static/icons/clock.svg'
import Palette from 'lucide-static/icons/palette.svg'
import * as ICONS from 'imba-phosphor-icons'

import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import activities from '../lib/Activities'
import settings from '../lib/Settings'
import vault from '../lib/Vault'
import user from '../lib/User'
import readingHistory from '../lib/ReadingHistory'


tag books-modal
	unfoldTranslationsList = no
	unfoldedLanguage = ''
	modalState = 'book' # 'book' | 'chapter' | 'verse'
	selectedBook = null # number | null
	selectedChapter = null # number | null
	colorsEnabled = no
	mode = 'browse' # 'browse' | 'history'
	textEnlarged = no
	searchQuery = ''

	@computed get activeTranslation
		if activities.activeParallelAtBooksDrawer && parallelReader.enabled
			return parallelReader.translation
		return reader.translation || 'YLT'

	@computed get books
		unless ALL_BOOKS[activeTranslation]
			return ALL_BOOKS['YLT']
		let orderBy = settings.chronorder ? 'chronorder' : 'bookid'
		return ALL_BOOKS[activeTranslation].sort(do(a, b) return a[orderBy] - b[orderBy])

	@computed get activeLanguage
		return languages.find(do(lang)
			return lang.translations.find(do|translation| translation.short_name == activeTranslation)
		).language

	@computed get activeBook
		if activeTranslation == parallelReader.translation
			return parallelReader.book
		return reader.book

	@computed get activeChapter
		if activeTranslation == parallelReader.translation
			return parallelReader.chapter
		return reader.chapter

	@computed get oldTestamentBooks
		return books.filter(do(book) return book.bookid <= 39)

	@computed get newTestamentBooks
		return books.filter(do(book) return book.bookid > 39)

	def getBookColorClass bookNumber\number
		unless colorsEnabled
			return ''
		# Gen-Deu (1-5) → red
		if bookNumber >= 1 and bookNumber <= 5
			return 'bible-color-red'
		# Jos-Est (6-17) → blue
		if bookNumber >= 6 and bookNumber <= 17
			return 'bible-color-blue'
		# Job-SoS (18-22) → orange
		if bookNumber >= 18 and bookNumber <= 22
			return 'bible-color-orange'
		# Isa-Dan (23-27) → purple
		if bookNumber >= 23 and bookNumber <= 27
			return 'bible-color-purple'
		# Hos-Mal (28-39) → green
		if bookNumber >= 28 and bookNumber <= 39
			return 'bible-color-green'
		# Mat-John (40-43) → red
		if bookNumber >= 40 and bookNumber <= 43
			return 'bible-color-red'
		# Act (44) → blue
		if bookNumber == 44
			return 'bible-color-blue'
		# Rom-2Th (45-53) → orange
		if bookNumber >= 45 and bookNumber <= 53
			return 'bible-color-orange'
		# 1Ti-Phm (54-57) → purple
		if bookNumber >= 54 and bookNumber <= 57
			return 'bible-color-purple'
		# Heb-Rev (58-66) → green
		if bookNumber >= 58 and bookNumber <= 66
			return 'bible-color-green'
		return ''

	# Book abbreviation mapping (similar to Obsidian plugin)
	def getBookAbbreviation bookNumber\number
		const abbreviations = {
			1: "GEN", 2: "EX", 3: "LEV", 4: "NUM", 5: "DEU",
			6: "JOS", 7: "JDG", 8: "RTH", 9: "1SA", 10: "2SA",
			11: "1KI", 12: "2KI", 13: "1CH", 14: "2CH", 15: "EZR",
			16: "NEH", 17: "EST", 18: "JOB", 19: "PSA", 20: "PRV",
			21: "ECC", 22: "SOS", 23: "ISA", 24: "JER", 25: "LAM",
			26: "EZE", 27: "DAN", 28: "HOS", 29: "JOE", 30: "AMO",
			31: "OBD", 32: "JON", 33: "MIC", 34: "NAH", 35: "HAB",
			36: "ZEP", 37: "HAG", 38: "ZEC", 39: "MAL",
			40: "MAT", 41: "MRK", 42: "LUK", 43: "JN",
			44: "ACT", 45: "ROM", 46: "1CO", 47: "2CO", 48: "GAL",
			49: "EPH", 50: "PHP", 51: "COL", 52: "1TH", 53: "2TH",
			54: "1TI", 55: "2TI", 56: "TIT", 57: "PHM",
			58: "HEB", 59: "JAM", 60: "1PE", 61: "2PE", 62: "1JN",
			63: "2JN", 64: "3JN", 65: "JUD", 66: "REV"
		}
		return abbreviations[bookNumber] || "???"

	def setActiveTranslation parallel\boolean
		activities.activeParallelAtBooksDrawer = parallel

	@action def swapTranslations
		let main_translation = reader.translation
		let main_book = reader.book
		let main_chapter = reader.chapter
		
		reader.translation = parallelReader.translation
		reader.book = parallelReader.book
		reader.chapter = parallelReader.chapter

		parallelReader.translation = main_translation
		parallelReader.book = main_book
		parallelReader.chapter = main_chapter
	
	def toggleChronorder
		settings.chronorder = !settings.chronorder
		# Reset state when changing order
		modalState = 'book'
		selectedBook = null
		selectedChapter = null
	
	@action def toggleMode newMode\string
		mode = newMode
		searchQuery = ''
		modalState = 'book'
		selectedBook = null
		selectedChapter = null
	
	@action def toggleColors
		colorsEnabled = !colorsEnabled
	
	@action def toggleTextEnlarged
		textEnlarged = !textEnlarged
	
	@computed get filteredHistory
		unless searchQuery.trim()
			return readingHistory.history.slice(0, 10)
		
		const query = searchQuery.toLowerCase()
		return readingHistory.history.filter(do(item)
			const book = ALL_BOOKS[item.translation]?.find(do(b) return b.bookid == item.book)
			if !book
				return no
			const bookName = book.name.toLowerCase()
			const abbr = getBookAbbreviation(item.book).toLowerCase()
			return bookName.includes(query) or abbr.includes(query) or item.chapter.toString().includes(query) or (item.verse and item.verse.toString().includes(query))
		).slice(0, 10)

	def toggleLanguageTranslations language\string
		if language != unfoldedLanguage
			unfoldedLanguage = language
		else unfoldedLanguage = ''

	def translationHeartFill trabbr\string
		if settings.favoriteTranslations.includes(trabbr)
			return 'currentColor'
		return 'none'

	def toggleTranslationFavor translation_short_name\string
		if translation_short_name in settings.favoriteTranslations
			settings.favoriteTranslations.splice(settings.favoriteTranslations.indexOf(translation_short_name), 1)
		else
			settings.favoriteTranslations.push(translation_short_name)

	@action def changeTranslation translation\string
		if parallelReader.enabled && activeTranslation == parallelReader.translation
			unless ALL_BOOKS[translation].find(do |element| return element.bookid == parallelReader.book)
				parallelReader.book = ALL_BOOKS[translation][0].bookid
				parallelReader.chapter = 1
			parallelReader.translation = translation
		else
			unless ALL_BOOKS[translation].find(do |element| return element.bookid == reader.book)
				reader.book = ALL_BOOKS[translation][0].bookid
				reader.chapter = 1
			reader.translation = translation
		unfoldTranslationsList = no
		# Reset state when changing translation
		modalState = 'book'
		selectedBook = null
		selectedChapter = null

	@action def selectBook bookIndex\number
		selectedBook = bookIndex
		selectedChapter = null
		modalState = 'chapter'

	@action def selectChapter chapterIndex\number
		if selectedBook != null
			const book = books[selectedBook]
			if book
				goToChapter(book.bookid, chapterIndex + 1)

	@action def goToChapter bookid\number, chapter\number
		if parallelReader.enabled && activeTranslation == parallelReader.translation
			parallelReader.book = bookid
			parallelReader.chapter = chapter
		else
			reader.book = bookid
			reader.chapter = chapter
		activities.cleanUp!
	
	@action def goToChapterFromHistory bookid\number, chapter\number, translation\string
		# Change translation if needed
		if translation != activeTranslation
			changeTranslation(translation)
		goToChapter(bookid, chapter)

	@action def goBack
		if modalState == 'verse'
			modalState = 'chapter'
			selectedChapter = null
		elif modalState == 'chapter'
			modalState = 'book'
			selectedBook = null
			selectedChapter = null

	<self>
		<button.bible-close-btn.bible-close-corner @click=activities.cleanUp title=t.close aria-label=t.close>
			<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
		<button.bible-back-btn.bible-back-corner @click=goBack
			[pointer-events:{(modalState == 'book') ? 'none' : 'auto'}]
			[opacity:{(modalState == 'book') ? 0.5 : 1}]
			title=t.back
			aria-label=t.back>
			<svg src=ArrowLeft aria-hidden=true>
		<[d:flex jc:center ai:center g:0.5rem flex-wrap:nowrap].bible-top-buttons>
			<button.bible-mode-btn .active=(mode == 'browse') @click=toggleMode('browse') title="Browse">
				<span.bible-mode-icon>
					<svg src=BookOpen width="18" height="18" aria-hidden=true>
			<button.bible-mode-btn .active=(mode == 'history') @click=toggleMode('history') title="History">
				<span.bible-mode-icon>
					<svg src=Clock width="18" height="18" aria-hidden=true>
			<button.bible-mode-btn .active=colorsEnabled @click=toggleColors title="Color palette">
				<span.bible-mode-icon>
					<svg src=Palette width="18" height="18" aria-hidden=true>
			<button.bible-mode-btn.bible-enlarge-text-btn .active=textEnlarged @click=toggleTextEnlarged title="Enlarge text">
				<span.bible-mode-icon [d:flex ai:center g:2px fs:14px lh:1]>
					<span [fs:12px]> "A"
					<span [fs:16px fw:bold]> "A"
			<button.bible-mode-btn .active=settings.chronorder @click=toggleChronorder title=t.chronological_order aria-label=t.chronological_order>
				<span.bible-mode-icon>
					<svg src=Calendar width="18" height="18" aria-hidden=true>
			if vault.available
				<button.bible-mode-btn @click=activities.toggleDownloads title=t.download aria-label=t.download>
					<span.bible-mode-icon>
						<svg src=Download width="18" height="18" aria-hidden=true>
		<header>
			<[d:flex jc:center ai:center g:0.75rem]>
				if selectedBook != null and books[selectedBook]
					<span.bible-selected-book-name> books[selectedBook].name
					<span.bible-separator> "|"
				if parallelReader.enabled
					<[d:flex mih:2.25rem g:0.5rem]>
						<button.btn title=translationFullName(reader.translation) .active=(activeTranslation == reader.translation) @click=setActiveTranslation(no)> reader.translation
						<button.btn [fw:black] @click=swapTranslations title=t.swap_parallels> "⇄"
						<button.btn title=translationFullName(parallelReader.translation) .active=(activeTranslation == parallelReader.translation) @click=setActiveTranslation(yes)> parallelReader.translation
				else
					<button.btn title=t.change_translation @click=(unfoldTranslationsList = !unfoldTranslationsList)>
						activeTranslation
						<svg[min-width:1rem h:1.1em mb:-0.2em transform:rotate({180 * +unfoldTranslationsList}deg)] src=ChevronDown aria-label="">
		
		<article.body.bible-modal-slider .bible-text-enlarged=textEnlarged .bible-translations-open=unfoldTranslationsList .bible-enlarged-scroll=textEnlarged>
			if mode == 'history'
				<div.bible-history-results>
					<input.bible-modal-input
						type="text"
						placeholder="Search history or type a reference…"
						bind=searchQuery
						aria-label="Search history">
					<div.bible-history-list>
						if filteredHistory.length > 0
							for item in filteredHistory
								const bookData = ALL_BOOKS[item.translation]?.find(do(b) return b.bookid == item.book)
								if bookData
									<div.bible-history-item @click=goToChapterFromHistory(item.book, item.chapter, item.translation)>
										<span.bible-history-item-icon>
											<svg src=BookOpen width="16" height="16" aria-hidden=true>
										<div.bible-history-item-text>
											<div.bible-history-item-primary> "{bookData.name} {item.chapter}"
											if item.verse
												<div.bible-history-item-secondary> "Verse {item.verse}"
											<div.bible-history-item-hint> item.translation
						else
							<div.bible-history-empty> "No history found"
			elif mode == 'browse' and unfoldTranslationsList
				<div[h:auto max-height:100% ofy:scroll -webkit-overflow-scrolling:touch pb:2rem]>
					if settings.favoriteTranslations.length
						<[d:flex flw:wrap ai:center p:0.5rem]>
							<svg src=Heart [size:1em stroke:$c fill:currentColor]>
							for favorite in settings.favoriteTranslations
								<span.li [w:auto p:0 .5rem] @click=changeTranslation(favorite)> favorite
					for language in languages
						<section key=language.language>
							<p.li .active=(language.language == activeLanguage) @click=toggleLanguageTranslations(language.language)>
								language.language
								<svg[min-width:1rem h:1.1em ml:auto mb:-0.2em transform:rotate({180 * +(language.language == unfoldedLanguage)}deg)] src=ChevronDown aria-label="">
							if language.language == unfoldedLanguage
								<ul [o@off:0 m:0 0 1rem @off:-1.5rem 0 1.5rem transition-timing-function:quad h@off:0px of:hidden] dir="auto" ease>
									for translation in language.translations
										if window.navigator.onLine || vault.downloaded_translations.indexOf(translation.short_name) != -1
											<li.li .active=(translation.short_name == activeTranslation) [display: flex]>
												<span @click=changeTranslation(translation.short_name)>
													<b> translation.short_name
													', '
													translation.full_name
												<[d:flex fld:column ml:.25rem]>
													<svg src=Heart [size:1em stroke:$c @hover:$acc-hover fill: {translationHeartFill(translation.short_name)}] @click.prevent.stop=toggleTranslationFavor(translation.short_name)>
									if vault.downloaded_translations.length == 0 && !window.navigator.onLine
										<p.li> t["no_translation_downloaded"]
			elif mode == 'browse' and modalState == 'book'
				<div.bible-showing-books>
					# Old Testament
					if oldTestamentBooks.length > 0
						<div.bible-testament-divider>
							<span.bible-testament-title> "Old Testament"
						<div.bible-book-grid>
							for book in oldTestamentBooks
								const bookIndex = books.indexOf(book)
								const isSelected = selectedBook == bookIndex or (selectedBook == null and book.bookid == activeBook)
								const colorClass = getBookColorClass(book.bookid)
								<button.bible-book-btn .bible-color-red=(colorClass == 'bible-color-red') .bible-color-blue=(colorClass == 'bible-color-blue') .bible-color-orange=(colorClass == 'bible-color-orange') .bible-color-purple=(colorClass == 'bible-color-purple') .bible-color-green=(colorClass == 'bible-color-green') .active=isSelected @click=selectBook(bookIndex)>
									<div.bible-book-abbreviation> getBookAbbreviation(book.bookid)
									<div.bible-book-name> book.name
					# New Testament
					if newTestamentBooks.length > 0
						<div.bible-testament-divider>
							<span.bible-testament-title> "New Testament"
						<div.bible-book-grid>
							for book in newTestamentBooks
								const bookIndex = books.indexOf(book)
								const isSelected = selectedBook == bookIndex or (selectedBook == null and book.bookid == activeBook)
								const colorClass = getBookColorClass(book.bookid)
								<button.bible-book-btn .bible-color-red=(colorClass == 'bible-color-red') .bible-color-blue=(colorClass == 'bible-color-blue') .bible-color-orange=(colorClass == 'bible-color-orange') .bible-color-purple=(colorClass == 'bible-color-purple') .bible-color-green=(colorClass == 'bible-color-green') .active=isSelected @click=selectBook(bookIndex)>
									<div.bible-book-abbreviation> getBookAbbreviation(book.bookid)
									<div.bible-book-name> book.name
			elif modalState == 'chapter' and selectedBook != null
				const book = books[selectedBook]
				if book
					<div.bible-chapter-divider>
					<div.bible-chapter-grid>
						for i in [0 ... book.chapters]
							const chapterNum = i + 1
							const isSelected = selectedChapter == i or (selectedChapter == null and chapterNum == activeChapter and book.bookid == activeBook)
							<button.bible-chapter-btn .active=isSelected @click=selectChapter(i)>
								chapterNum

	css
		.bible-top-buttons
			position: absolute
			top: 0.75rem
			left: 50%
			transform: translateX(-50%)
			z-index: 10
			display: flex
			align-items: center
			justify-content: center
			gap: 0.5rem
		
		header
			padding: 3.5rem 0.75rem 0.5rem 0.75rem
			min-height: auto
			overflow: hidden
			max-height: none
			display: flex
			justify-content: center
			align-items: center
		
		header > div
			width: auto
			flex-shrink: 0
			display: flex
			justify-content: center
			align-items: center
		
		.bible-back-btn
			display: flex
			align-items: center
			justify-content: center
			padding: 0.75rem
			min-width: 3rem
			min-height: 3rem
			border: none
			background: transparent
			cursor: pointer
			border-radius: 4px
			transition: background 0.15s ease
			-webkit-tap-highlight-color: transparent
		
		.bible-back-btn svg
			width: 1.75rem
			height: 1.75rem
		
		.bible-back-corner
			position: absolute
			top: 0.75rem
			left: 0.75rem
			z-index: 10
		
		.bible-back-btn@hover
			background: var(--background-modifier-hover, rgba(255, 255, 255, 0.1))
		
		.bible-back-btn@active
			background: var(--background-modifier-active, rgba(255, 255, 255, 0.15))
		
		.bible-separator
			color: var(--text-muted, rgba(255, 255, 255, 0.5))
			margin: 0 0.5rem
			font-size: 1rem
		
		.bible-modal-slider
			max-height: calc(85vh - 180px)
			overflow-y: hidden
			overflow-x: hidden
			padding: 4px 8px 8px 8px
			display: flex
			flex-direction: column
		
		.bible-modal-slider.bible-translations-open
			overflow-y: auto
			-webkit-overflow-scrolling: touch
		
		.bible-modal-slider.bible-enlarged-scroll
			overflow-y: auto
			-webkit-overflow-scrolling: touch
		
		.bible-showing-books
			padding: 0
			overflow-y: visible
			flex: 1
			display: flex
			flex-direction: column
			min-height: 0

		.bible-showing-books
			padding: 0

		.bible-book-grid
			display: grid
			grid-template-columns: repeat(7, 1fr)
			gap: 6px

		.bible-book-btn
			min-width: 30px
			height: 38px
			padding: 6px 8px
			border: none
			border-radius: 4px
			background: var(--background-modifier-form-field, rgba(255, 255, 255, 0.1))
			color: var(--text-normal, #ffffff)
			cursor: pointer
			transition: all 0.15s ease
			text-align: center
			display: flex
			flex-direction: column
			gap: 3px
			position: relative
			width: 100%
			align-items: center
			justify-content: center

		.bible-book-btn.active
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 25%, transparent)
		
		.bible-book-btn.active@hover
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 30%, transparent)

		.bible-book-btn.bible-color-red
			background: rgba(255, 118, 118, 0.3)

		.bible-book-btn.bible-color-blue
			background: rgba(118, 165, 255, 0.3)

		.bible-book-btn.bible-color-orange
			background: rgba(255, 183, 118, 0.3)

		.bible-book-btn.bible-color-purple
			background: rgba(200, 118, 255, 0.3)

		.bible-book-btn.bible-color-green
			background: rgba(118, 255, 165, 0.3)

		.bible-book-btn.bible-color-red@hover
			background: rgba(255, 118, 118, 0.45)

		.bible-book-btn.bible-color-blue@hover
			background: rgba(118, 165, 255, 0.45)

		.bible-book-btn.bible-color-orange@hover
			background: rgba(255, 183, 118, 0.45)

		.bible-book-btn.bible-color-purple@hover
			background: rgba(200, 118, 255, 0.45)

		.bible-book-btn.bible-color-green@hover
			background: rgba(118, 255, 165, 0.45)

		.bible-book-abbreviation
			font-size: 11px
			font-weight: 500
			color: #ffffff
			line-height: 1.1
			margin: 0

		.bible-book-name
			font-size: 9px
			color: rgba(255, 255, 255, 0.85)
			line-height: 1.1
			font-weight: 400
			text-align: center

		.bible-testament-divider
			display: flex
			align-items: center
			gap: 12px
			margin: 12px 0 12px 0
			color: rgba(255, 255, 255, 0.75)
			font-size: 11px
			text-transform: uppercase
			letter-spacing: 0.5px
			font-weight: 500
			width: 100%

		.bible-testament-title
			white-space: nowrap
			flex-shrink: 0

		.bible-testament-divider::before
			content: ''
			flex: 1
			height: 1px
			background: rgba(255, 255, 255, 0.35)
			min-width: 0

		.bible-testament-divider::after
			content: ''
			flex: 1
			height: 1px
			background: rgba(255, 255, 255, 0.35)
			min-width: 0

		.bible-testament-title
			font-weight: 500
			white-space: nowrap

		.bible-chapter-grid
			display: grid
			grid-template-columns: repeat(7, 1fr)
			gap: 6px

		.bible-chapter-divider
			display: flex
			align-items: center
			margin: 12px 0 12px 0

		.bible-chapter-divider::before,
		.bible-chapter-divider::after
			content: ''
			flex: 1
			height: 1px
			background: rgba(255, 255, 255, 0.35)

		.bible-chapter-btn
			min-width: 40px
			height: 38px
			padding: 6px 10px
			border: none
			border-radius: 4px
			background: var(--background-modifier-form-field, rgba(255, 255, 255, 0.1))
			color: var(--text-normal, #ffffff)
			font-weight: 500
			font-size: 13.5px
			cursor: pointer
			transition: all 0.15s ease
			text-align: center
			display: flex
			align-items: center
			justify-content: center

		.bible-chapter-btn.active
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 25%, transparent)
		
		.bible-chapter-btn.active@hover
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 30%, transparent)

		.bible-verse-grid
			display: grid
			grid-template-columns: repeat(7, 1fr)
			gap: 8px
			padding: 0

		.bible-verse-divider
			display: flex
			align-items: center
			margin: 12px 0 12px 0

		.bible-verse-divider::before,
		.bible-verse-divider::after
			content: ''
			flex: 1
			height: 1px
			background: rgba(255, 255, 255, 0.35)

		.bible-verse-btn
			min-width: 40px
			height: 38px
			padding: 6px 10px
			border: none
			border-radius: 4px
			background: var(--background-modifier-form-field, rgba(255, 255, 255, 0.1))
			color: var(--text-normal, #ffffff)
			font-weight: 500
			font-size: 13.5px
			cursor: pointer
			transition: all 0.15s ease
			text-align: center
			display: flex
			align-items: center
			justify-content: center

		.bible-verse-btn.active
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 25%, transparent)
		
		.bible-verse-btn.active@hover
			background: color-mix(in srgb, var(--interactive-accent, #7c3aed) 30%, transparent)


		.btn
			background-color: transparent
			border: none
			font-weight: bold
			text-align: center
			font-size: 1.25rem
			width: 100%
			padding: .5rem 0
			color: inherit @hover:$acc-hover
			cursor: pointer

		header > div > svg
			s:2rem
			p:0.25rem
			c@hover:$acc-hover
			cursor: pointer

		.bible-mode-btn
			display: flex
			align-items: center
			justify-content: center
			padding: 6px
			border: none
			background: transparent
			color: var(--text-normal, rgba(255, 255, 255, 0.7))
			cursor: pointer
			border-radius: 4px
			transition: all 0.2s ease
			font-size: 14px
			font-weight: 400
			min-width: 36px
			height: 36px

		.bible-mode-btn@hover
			background-color: var(--background-modifier-hover, rgba(255, 255, 255, 0.1))
			color: var(--text-on-accent, #ffffff)

		.bible-mode-btn.active
			background-color: var(--interactive-normal, rgba(255, 255, 255, 0.15))
			color: var(--text-on-accent, #ffffff)

		.bible-mode-btn.active@hover
			background-color: var(--interactive-normal, rgba(255, 255, 255, 0.2))
			color: var(--text-on-accent, #ffffff)

		.bible-mode-icon
			display: flex
			align-items: center
			justify-content: center
			width: 18px
			height: 18px

		.bible-mode-icon svg
			width: 100%
			height: 100%

		.bible-enlarge-text-btn .bible-mode-icon svg
			width: 20px
			height: 14px

		.bible-text-enlarged .bible-book-btn
			height: 44px

		.bible-text-enlarged .bible-book-abbreviation
			font-size: 16px

		.bible-text-enlarged .bible-book-name
			font-size: 12px

		.bible-text-enlarged .bible-chapter-btn
			height: 44px
			font-size: 16px

		.bible-text-enlarged .bible-verse-btn
			height: 44px
			font-size: 16px

		.bible-history-results
			display: flex
			flex-direction: column
			gap: 12px
			padding: 8px

		.bible-modal-input
			width: 100%
			padding: 8px 12px
			border: 1px solid var(--background-modifier-border, rgba(255, 255, 255, 0.2))
			border-radius: 4px
			background-color: var(--background-primary, rgba(255, 255, 255, 0.05))
			color: var(--text-normal, #ffffff)
			font-size: 14px
			outline: none
			transition: border-color 0.2s ease

		.bible-modal-input@focus
			border-color: var(--interactive-accent, #7c3aed)
			box-shadow: 0 0 0 2px var(--background-modifier-border, rgba(255, 255, 255, 0.1))

		.bible-history-list
			display: flex
			flex-direction: column
			gap: 4px
			max-height: calc(72vh - 150px)
			overflow-y: auto

		.bible-history-item
			display: flex
			align-items: center
			gap: 12px
			padding: 10px 12px
			border-radius: 4px
			background: transparent
			cursor: pointer
			transition: background-color 0.15s ease

		.bible-history-item@hover
			background-color: var(--background-modifier-hover, rgba(255, 255, 255, 0.1))

		.bible-history-item-icon
			display: flex
			align-items: center
			justify-content: center
			width: 20px
			height: 20px
			flex-shrink: 0
			color: var(--text-muted, rgba(255, 255, 255, 0.6))

		.bible-history-item-icon svg
			width: 100%
			height: 100%

		.bible-history-item-text
			display: flex
			flex-direction: column
			gap: 2px
			flex: 1
			min-width: 0

		.bible-history-item-primary
			font-size: 14.5px
			font-weight: 500
			color: var(--text-normal, #ffffff)
			line-height: 1.4

		.bible-history-item-secondary
			font-size: 11px
			color: var(--text-muted, rgba(255, 255, 255, 0.6))
			line-height: 1.4

		.bible-history-item-hint
			font-size: 10px
			color: var(--text-muted, rgba(255, 255, 255, 0.5))
			line-height: 1.4

		.bible-history-empty
			padding: 24px
			text-align: center
			color: var(--text-muted, rgba(255, 255, 255, 0.6))
			font-size: 14px

		.li
			d:hcs
			color:inherit
			background:inherit
			padding:0.75rem
			height:auto
			cursor:pointer
			width:100%
			fill:$c @hover:$acc-hover
			c@hover:$acc-hover
			font:inherit

			span 
				flex: 1
	
		.active
			c:$acc
		
		.bible-selected-book-name
			font-size: 1.25rem
			font-weight: bold
			color: inherit
			white-space: nowrap
		
		header .btn
			font-size: 1.25rem
			font-weight: bold
		
		.bible-close-btn
			display: flex
			align-items: center
			justify-content: center
			padding: 0.75rem
			min-width: 3rem
			min-height: 3rem
			border: none
			background: transparent
			cursor: pointer
			border-radius: 4px
			transition: background 0.15s ease
			-webkit-tap-highlight-color: transparent
		
		.bible-close-btn svg
			width: 1.75rem
			height: 1.75rem
		
		.bible-close-corner
			position: absolute
			top: 0.75rem
			right: 0.75rem
			z-index: 10
		
		.bible-close-btn@hover
			background: var(--background-modifier-hover, rgba(255, 255, 255, 0.1))
		
		.bible-close-btn@active
			background: var(--background-modifier-active, rgba(255, 255, 255, 0.15))
		
		.bible-close-btn svg
			width: 1.5rem
			height: 1.5rem
		
		.bible-close-btn svg
			width: 1.5rem
			height: 1.5rem
