import languages from '../data/languages.json'
import ALL_BOOKS from '../data/translations_books.json'

import HourGlassIcon from 'lucide-static/icons/hourglass.svg'
import Download from 'lucide-static/icons/download.svg'
import Heart from 'lucide-static/icons/heart.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import readingHistory from '../lib/ReadingHistory'

tag books-drawer < nav
	unfoldTranslationsList = no
	unfoldedLanguage = ''
	unfoldedBook = reader.book

	@computed get activeTranslation
		if activities.activeParallelAtBooksDrawer && parallelReader.enabled
			return parallelReader.translation
		return reader.translation || 'YLT'

	@computed get books
		unless ALL_BOOKS[activeTranslation]
			console.log "Active Translation {activeTranslation} not found in ALL_BOOKS, defaulting to YLT"
			return ALL_BOOKS['YLT']
		let orderBy = settings.chronorder ? 'chronorder' : 'bookid'
		return ALL_BOOKS[activeTranslation].sort(do(a, b) return a[orderBy] - b[orderBy])

	@computed get activeLanguage
		return languages.find(do(lang)
			return lang.translations.find(do|translation| translation.short_name == activeTranslation)
		).language

	@computed get activeBook
		if activeTranslation == parallelReader.translation
			unfoldedBook = parallelReader.book
			return parallelReader.book
		unfoldedBook = reader.book
		return reader.book

	@computed get activeChapter
		if activeTranslation == parallelReader.translation
			return parallelReader.chapter
		return reader.chapter

	def isCurrentTranslation translation\string
		if parallelReader.enabled
			if activeTranslation == parallelReader.translation
				return translation == parallelReader.translation
			else
				return translation == reader.translation
		else
			return translation == reader.translation

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

	def isTranslationAvailable short_name\string
		return window.navigator.onLine || vault.downloaded_translations.indexOf(short_name) != -1

	def findTranslation short_name\string
		for language in languages
			for translation in language.translations
				if translation.short_name == short_name
					return translation
		return null

	@computed get recentTranslationItems
		let items = []
		let seen = new Set()
		def addShortName short_name
			if seen.has(short_name) or !isTranslationAvailable(short_name)
				return
			let translation = findTranslation(short_name)
			if translation
				seen.add(short_name)
				items.push(translation)
		for short_name in settings.recentTranslations
			addShortName(short_name)
			if items.length >= 7
				return items
		for item in readingHistory.history
			addShortName(item.translation)
			if items.length >= 7
				break
		return items

	@computed get favoriteTranslationItems
		let items = []
		for short_name in settings.favoriteTranslations
			unless isTranslationAvailable(short_name)
				continue
			let translation = findTranslation(short_name)
			if translation
				items.push(translation)
		return items

	@action def changeTranslation translation\string
		if parallelReader.enabled && activeTranslation == parallelReader.translation
			unless parallelReader.applyTranslationChange(translation)
				return
		else
			unless reader.applyTranslationChange(translation)
				return
		settings.recordRecentTranslation(translation)
		unfoldTranslationsList = no

	@action def goToChapter bookid\number, chapter\number
		if parallelReader.enabled && activeTranslation == parallelReader.translation
			parallelReader.book = bookid
			parallelReader.chapter = chapter
		else
			reader.book = bookid
			reader.chapter = chapter

	<self [right@important: 0]=settings.lock_books_menu>
		<header>
			if parallelReader.enabled
				<[d:flex mih:2.25rem]>
					<button.btn title=translationFullName(reader.translation) .active=(activeTranslation == reader.translation) @click=setActiveTranslation(no)> reader.translation
					<button.btn [fw:black w:40%] @click=swapTranslations title=t.swap_parallels> "⇄"
					<button.btn title=translationFullName(parallelReader.translation) .active=(activeTranslation == parallelReader.translation) @click=setActiveTranslation(yes)> parallelReader.translation
			<[d:flex jc:space-between ai:center cursor:pointer padding-inline:0.5rem]>
				<svg src=HourGlassIcon
					[transform:rotate({63 * (1 - +settings.chronorder)}deg)]
					@click=toggleChronorder
					aria-label=t.chronological_order>
				<button.btn title=t.change_translation @click=(unfoldTranslationsList = !unfoldTranslationsList)>
					activeTranslation
					<svg[min-width:1rem h:1.1em mb:-0.2em transform:rotate({180 * +unfoldTranslationsList}deg)] src=ChevronDown aria-label="">
				if vault.available
					<svg src=Download role="button" @click=activities.toggleDownloads aria-label=t.download>
			
		if unfoldTranslationsList
			<div[h:auto max-height:100% @off:0px o@off:0 ofy:scroll @off:hidden -webkit-overflow-scrolling:touch pb:8rem @off:0 y@off:-2rem] ease>
				if favoriteTranslationItems.length
					<p.bible-translations-section-title> t.favorite_translations
					<ul dir="auto">
						for translation in favoriteTranslationItems
							<li.li .active=(translation.short_name == activeTranslation) [display: flex]>
								<span @click=changeTranslation(translation.short_name)>
									<b> translation.short_name
									', '
									translation.full_name
								<[d:flex fld:column ml:.25rem]>
									<svg src=Heart [size:1em stroke:$c @hover:$acc-hover fill: {translationHeartFill(translation.short_name)}] @click.prevent.stop=toggleTranslationFavor(translation.short_name)>
					<div.bible-translations-divider>
				if recentTranslationItems.length
					<p.bible-translations-section-title> t.most_recent_translations
					<ul dir="auto">
						for translation in recentTranslationItems
							<li.li .active=(translation.short_name == activeTranslation) [display: flex]>
								<span @click=changeTranslation(translation.short_name)>
									<b> translation.short_name
									', '
									translation.full_name
								<[d:flex fld:column ml:.25rem]>
									<svg src=Heart [size:1em stroke:$c @hover:$acc-hover fill: {translationHeartFill(translation.short_name)}] @click.prevent.stop=toggleTranslationFavor(translation.short_name)>
					<div.bible-translations-divider>
				<p.bible-translations-section-title> t.all_translations
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
		else
			<ul[h:auto max-height:100% @off:0px o@off:0 ofy:scroll @off:hidden -webkit-overflow-scrolling:touch pb:8rem @off:0 y@off:-2rem] ease>
				for book, index in books
					<li key=book.bookid>
						<p.li dir="auto" .active=(book.bookid == activeBook) @click=(unfoldedBook = book.bookid)> book.name
						if book.bookid == unfoldedBook
							<ul[o@off:0 m:0 0 1rem @off:-1.5rem 0 1.5rem transition-timing-function:quad h@off:0px of:hidden] dir="auto" ease>
								for i in [0 ... book.chapters]
									<li .active=(i + 1 == activeChapter && book.bookid == activeBook) @click=goToChapter(book.bookid, i+1)>
										css
											cursor:pointer
											d:inline-block ta:center
											c@hover:$acc-hover
											h:3.375rem w:20%
											fs:1.25rem pt:1rem
											pos:relative
										i+1
										if user.bookmarksMap[activeTranslation] and user.bookmarksMap[activeTranslation][book.bookid] and user.bookmarksMap[activeTranslation][book.bookid][i+1]
											<div[pos:absolute d:flex jc:center g:2px r:0 l:0 maw:100% flw:wrap mah:2rem of:hidden p:.25rem] aria-hidden=true>
												for color in user.bookmarksMap[activeTranslation][book.bookid][i+1]
													<span [bgc:{color} d:block s:0.375rem rd:50%]>

						if book.bookid == 39
							<pre[d:flex jc:center] aria-hidden=true>
								"≽^•⩊•^≼"
						if index == 65
							<pre[d:flex jc:center] aria-hidden=true>
								"-ˋˏ ༻⟡༺ ˎˊ-"

		unless activities.booksDrawerOffset
			<global @click.outside.capture.stop.prevent=activities.toggleBooksMenu>

	css
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

		.bible-translations-divider
			height: 1px
			background: $acc-bgc
			opacity: 0.65
			margin: 0.5rem 0.75rem 0.75rem

		.bible-translations-section-title
			margin: 0
			padding: 0.25rem 0.75rem 0.35rem
			font-size: 11px
			text-transform: uppercase
			letter-spacing: 0.5px
			font-weight: 500
			opacity: 0.75
			color: inherit
