import Search from 'lucide-static/icons/search.svg'
import Download from 'lucide-static/icons/download.svg'
import ChevronRight from 'lucide-static/icons/chevron-right.svg'
import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import CaseSensitive from 'lucide-static/icons/case-sensitive.svg'
import WholeWord from 'lucide-static/icons/whole-word.svg'
import SquareSplitHorizontal from 'lucide-static/icons/square-split-horizontal.svg'
import Filter from 'lucide-static/icons/list-filter.svg'
import Copy from 'lucide-static/icons/copy.svg'
import ListPlus from 'lucide-static/icons/list-plus.svg'
import Send from 'lucide-static/icons/send.svg'
import LoaderPinwheel from 'lucide-static/icons/loader-pinwheel.svg'
import Check from 'lucide-static/icons/check.svg'
import Bookmark from 'lucide-static/icons/bookmark.svg'
import Obsidian from '../icons/obsidian.svg'
import { format } from 'date-fns'
import Color from "colorjs.io"

import languages from '../data/languages.json'
import { hasTouchEvents, translations, contributors } from '../constants'
import ALL_BOOKS from '../data/translations_books.json'
import type { HistoryEntry } from '../lib/types'

import * as ICONS from 'imba-phosphor-icons'

tag modal < section
	fontsQuery = ''
	expandedLanguage = ''

	@action def changeTranslation translation\string
		unless reader.applyTranslationChange(translation)
			return
		reader.syncMainTabState!

	@action def openTranslationInParallel translation\string
		parallelReader.enable = yes
		unless ALL_BOOKS[translation].find(do |element| return element.bookid == parallelReader.book)
			parallelReader.book = ALL_BOOKS[translation][0].bookid
			parallelReader.chapter = 1
		parallelReader.translation = translation

	@action def openVerseInParallel verse\{book:number, chapter:number, verse:number}
		# weirdly enough this has to be called through reader, otherwie it can backfire
		if settings.parallel_sync && parallelReader.enabled
			reader.book = verse.book
			reader.chapter = verse.chapter
			reader.verse = verse.verse
		else
			parallelReader.enable = yes
			parallelReader.book = verse.book
			parallelReader.chapter = verse.chapter
			parallelReader.verse = verse.verse
	
	def copyComparisonList
		let msg = activities.selectedVersesTitle

		for translation in compare.list
			let verses = []
			let texts = []
			for verse in translation
				if verse.text
					texts.push(verse.text)
					verses.push(verse.verse)
			const firstVerse = translation[0]
			if firstVerse.text
				msg += '\n\n«' + activities.cleanUpCopyTexts(texts) + '»\n\n' + firstVerse.translation + ' ' + "https://bolls.life" + '/'+ firstVerse.translation + '/' + firstVerse.book + '/' + firstVerse.chapter + '/' + activities.versesRange(verses) + '/'

		activities.copyTextToClipboard(msg)

	def filterCompareTranslation translation\(typeof translations[0])
		if compare.translations.find(do |element| return element == translation.short_name)
			return 0
		unless compare.search.length
			return 1
		else
			return compare.search.toLowerCase() in (translation.short_name + translation.full_name).toLowerCase()

	def filterCompareLanguage language\(typeof languages[0])
		if language.translations.every(do(translation) filterCompareTranslation(translation) == 0)
			return 0
		unless compare.search.length
			return 1
		else
			return compare.search.toLowerCase() in language.language.toLowerCase() or language.translations.some(do(translation) filterCompareTranslation(translation) == 0)

	def openDictionariesDownloads
		activities.cleanUp!
		activities.activeModal = 'downloads'
		activities.show_dictionary_downloads = yes

	def expandLanguageDownloads language\string
		if language != expandedLanguage
			expandedLanguage = language
		else expandedLanguage = ''



	def translationDownloadStatus translation\string
		if vault.translationsDownloadQueue.find(do |tr| return tr == translation)
			return 'processing'
		elif vault.downloaded_translations.indexOf(translation) != -1
			return 'delete'
		else
			return 'download'

	def dictionaryDownloadStatus dictionary\string
		if vault.dictionariesDownloadQueue.find(do |tr| return tr == dictionary)
			return 'processing'
		elif vault.downloaded_dictionaries.indexOf(dictionary) != -1
			return 'delete'
		else
			return 'download'

	def offlineTranslationAction tr\string
		if vault.translationsDownloadQueue.find(do |translation| return translation == tr)
			return
		elif vault.downloaded_translations.indexOf(tr) != -1
			vault.deleteTranslation(tr)
		else
			vault.downloadTranslation(tr)

	def offlineDictionaryAction dict\string
		if vault.dictionariesDownloadQueue.find(do |translation| return translation == dict)
			return
		elif vault.downloaded_dictionaries.indexOf(dict) != -1
			vault.deleteDictionary(dict)
		else
			vault.downloadDictionary(dict)

	def downloadStatusIcon status\string
		switch status
			when 'processing'
				return <svg.spin src=LoaderPinwheel aria-hidden=yes>
			when 'delete'
				return <svg src=ICONS.TRASH aria-hidden=yes>
			else
				return <svg src=Download aria-hidden=yes>

	def deleteAllDownloads
		const confirmation = window.confirm((activities.show_dictionary_downloads ? t.remove_all_dictionaries : t.remove_all_translations) + '\n\n' + t.are_you_sure)
		unless confirmation
			return
		if activities.show_dictionary_downloads
			vault.clearDictionariesTable!
		else
			vault.clearVersesTable!

	def openDictionaryDownloads
		activities.openModal 'downloads'
		activities.show_dictionary_downloads = yes

	def definitionPlainText html\string
		unless html
			return ''
		let text = String(html)
		text = text.replace(/<(br|BR)\s*\/?>/g, '\n')
		text = text.replace(/<\/(p|div|li|h[1-6]|tr)>/gi, '\n')
		text = text.replace(/<li[^>]*>/gi, '- ')
		text = activities.cleanUpCopyText(text)
		text = text.replace(/\u00a0/g, ' ')
		text = text.replace(/[ \t]+\n/g, '\n')
		text = text.replace(/\n{3,}/g, '\n\n')
		return text.trim()

	def dictionaryEntryForObsidian
		unless dictionary.definitions and dictionary.definitions.length
			return null
		if dictionary.expandedTopic
			const expanded = dictionary.definitions.find(do |entry| return entry.topic == dictionary.expandedTopic)
			if expanded
				return expanded
		return dictionary.definitions[0]

	def sendDictionaryToObsidian
		const entry = dictionaryEntryForObsidian!
		unless entry
			return
		const definitionText = definitionPlainText(entry.definition)
		unless definitionText
			return
		const headingBits = []
		if entry.lexeme
			headingBits.push(String(entry.lexeme))
		if entry.pronunciation
			headingBits.push(String(entry.pronunciation))
		if entry.transliteration
			headingBits.push(String(entry.transliteration))
		if entry.short_definition
			headingBits.push(String(entry.short_definition))
		const messageToSend = {
			type: 'bible-dictionary-selection'
			dictionary: String(dictionary.currentDictionary or '')
			dictionaryName: String(dictionary.currentDictionaryName() or dictionary.currentDictionary or '')
			query: String(dictionary.query or '')
			topic: String(entry.topic or dictionary.query or '')
			heading: headingBits.join(' · ')
			definition: definitionText
			translation: String(reader.translation or '')
			book: String(reader.nameOfCurrentBook or '')
			chapter: Number(reader.chapter or 1)
			bookId: Number(reader.book or 1)
			verse: Number(reader.verse or 1)
		}
		try
			window.parent.postMessage(messageToSend, '*')
		catch err
			try
				window.parent.postMessage(JSON.parse(JSON.stringify(messageToSend)), '*')
			catch fallbackError
				pass
		if window.parent == window
			const title = [messageToSend.dictionary, messageToSend.topic].filter(do |bit| return bit).join(' · ')
			const lines = [title]
			if messageToSend.heading
				lines.push(messageToSend.heading)
			lines.push('')
			lines.push(messageToSend.definition)
			activities.copyTextToClipboard(lines.join('\n'))

	get backdropColor
		# get --bgc css variable value from dom
		const bgc = window.getComputedStyle(document.documentElement).getPropertyValue('--bgc')
		const color = new Color(bgc)
		color.alpha = 0.5
		return color.to("hsl").toString()
	
	def openSuggestedBook bookId\string
		reader.book=bookId
		reader.chapter=search.suggestions.chapter
		reader.verse=search.suggestions.verse
	
	def openSuggestedBookInParallel bookId\string
		openInParallel({
			translation:search.suggestions.translation,
			book: bookId,
			chapter: search.suggestions.chapter,
			verse: search.suggestions.verse
		})
	
	@action def openHistoryEntry history\HistoryEntry
		reader.translation = history.translation
		reader.book = history.book
		reader.chapter = history.chapter
		reader.verse = history.verse

	def render
		<self
			[pos:fixed inset:0 bg:{backdropColor} h:100% d:flex ai:flex-start jc:center p:6vh 0 @lt-sm:0 o@off:0 zi:1200]
			@click=activities.cleanUp ease>

			<[
				pos:relative
				d:flex fld:column
				max-height:{(activities.activeModal == 'books' or activities.activeModal == 'bookmarks') ? '85vh' : '72vh'} @lt-sm:100vh
				h:{activities.activeModal == 'bookmarks' ? '85vh' : 'auto'} @lt-sm:100vh
				block-size@lt-sm:100vh
				max-width:{(activities.activeModal == 'books' or activities.activeModal == 'bookmarks') ? '75em' : '64em'} @lt-sm:100%
				w:82% @lt-sm:100%
				bgc:$bgc bd:1px solid $acc-bgc-hover @lt-sm:none
				bxs: 0 0 0 1px $acc-bgc, 0 1px 6px $acc-bgc, 0 3px 36px $acc-bgc, 0 9px 12.5rem -4rem $acc-bgc @lt-sm:none
				rd:1rem @lt-sm:0
				p:1.5rem @lt-sm:0.75rem
				# Books modal uses container-level scroll.
				# Bookmarks modal handles scroll inside its own .bookmarks-content area.
				overflow-y:{(activities.activeModal == 'books') ? 'auto' : ((activities.activeModal == 'bookmarks') ? 'hidden' : 'visible')}
				margin:0
				scale@off:0.95] @click.stop>

				switch activities.activeModal
					when 'books'
						<books-modal>
					when 'bookmarks'
						<bookmarks-modal>
					when 'gotobook'
						<header#gotobook-header [pos:relative] @keydown=(do |e| goToBook.handleKeydown(e))>
							<button.focusable[c@hover:red4] @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X aria-hidden=yes>

							<input id="gotobooksearch"
								[direction:{textDirection(goToBook.query)}]
								type='text' placeholder="Type book, chapter and verse" aria-label="Go to book"
								bind=goToBook.query @keydown=(do |e| goToBook.handleKeydown(e))>

							if goToBook.suggestions.books..length or goToBook.suggestions.recent..length
								<ul.suggestions>
									for book, index in goToBook.suggestions.books
										<li>
											<p.li.focusable .selected=(goToBook.selectedIndex == index) tabIndex="0"
												@keydown.enter=goToBook.goToBook(book)
												@click=goToBook.goToBook(book)
												> goToBook.getSuggestionText(book)

									for recent, rindex in goToBook.suggestions.recent
										let itemIndex = (goToBook.suggestions.books ? goToBook.suggestions.books.length : 0) + rindex
										<li>
											<p.li.focusable .selected=(goToBook.selectedIndex == itemIndex) tabIndex="0"
												@keydown.enter=goToBook.goToRecentSearch(recent)
												@click=goToBook.goToRecentSearch(recent)
												> recent

							<button.focusable.gotobook-go-btn @click=goToBook.run title="Go">
								"Go"

					when 'help'
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2> t.help
							<a target="_blank" href="mailto:bpavlisinec@gmail.com" title=t.help>
								<svg src=Send aria-hidden=yes>

						<article.body.rich-text>
							<h3> t.content
							<ul>
								for q in t.HB
									<li> <a href="#{q[0]}"> q[0]
								if !hasTouchEvents
									<li> <a href="#shortcuts"> t.shortcuts
							for q in t.HB
								<h3 id=q[0] > q[0]
								<p innerHTML=q[1]>
							if !hasTouchEvents
								<h3 id="shortcuts"> t.shortcuts
								for shortcut in t.shortcuts_list
									<p> <span innerHTML=shortcut>
							<address[margin-block:4rem 1rem]>
								t.still_have_questions
								<a target="_blank" href="mailto:bpavlisinec@gmail.com"> " bpavlisinec@gmail.com"

					when 'compare'
						<header [pos:relative]>
							<h2 [ml:unset]> activities.compareVersesTitle(compare.versesToCompare)

							<menu-popup bind=activities.show_comparison_options>
								<button @click=(do activities.show_comparison_options = !activities.show_comparison_options) title=t.compare>
									<svg src=ListPlus aria-hidden=yes>
								if activities.show_comparison_options
									<.popup-menu [t:0 y@off:-2rem o@off:0 mah:72vh @lt-sm:96vh of:auto] ease>
										<header[d:flex bg:$bgc pos:sticky t:0 padding-inline-end:0.5rem]>
											<input bind=compare.search placeholder=t.search>
											<button[p:0] title=t.close @click=(activities.show_comparison_options = no)>
												<svg src=ICONS.X [c@hover:red4] aria-hidden=yes>

										if compare.translations.length > translations.length
											<p[padding: 0.75rem .5rem]> t.nothing_else

										for language in languages when filterCompareLanguage(language)
											<button
												[d:hcs w:100% fs:0.9rem o:.75 p:0.5rem padding-block:1.5rem 0 tt:uppercase ls:1px fw:bold]
												@click=compare.addAllTranslations(language)>
												language.language
												<svg src=ICONS.PLUS width="1.5rem" height="1.5rem">

											for translation in language.translations when filterCompareTranslation(translation)
												<button[w:100% p:0.5rem] @click=compare.toggleTranslation(translation)>
													<strong> translation.short_name
													', ', translation.full_name

							<button @click=copyComparisonList title=t.copy_all>
								<svg src=Copy aria-hidden=yes>

							<button[c@hover:red4] @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X aria-hidden=yes>

						<article.body id="compare" [scroll-behavior:auto]>
							<p[o:0.75 mb:.5rem]> t.add_translations_msg

							<orderable-list>

							unless compare.translations.length
								<button[m:1rem auto d:flex].more_results @click=(do activities.show_comparison_options = !activities.show_comparison_options)> t.add_translation_btn

					when 'downloads'
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=yes>
							<h2[transform@important:none pos:relative c@hover:$acc-hover fill:$c @hover:$acc-hover cursor:pointer d:flex w:100% jc:center ai:center us:none]
								@click=(activities.show_dictionary_downloads = !activities.show_dictionary_downloads)>
								<span>
									if activities.show_dictionary_downloads
										t.download_dictionaries
									else
										t.download_translations
								<svg src=ChevronDown aria-hidden=yes>

							if vault.deletingEverything
								<svg.spin src=LoaderPinwheel>
									<title> t.loading
							else
								<button @click=deleteAllDownloads title=(activities.show_dictionary_downloads ? t.remove_all_dictionaries : t.remove_all_translations)>
									<svg src=ICONS.TRASH [c@hover:red4] aria-hidden=yes>

						<ul.body>
							if activities.show_dictionary_downloads
								let no_dictionary_downloaded = yes
								for dictionary in dictionary.dictionaries when window.navigator.onLine || state.downloaded_dictionaries.indexOf(dictionary.abbr) != -1
									no_dictionary_downloaded = no
									<button.downloadListItem @click=offlineDictionaryAction(dictionary.abbr)>
										const status = dictionaryDownloadStatus(dictionary.abbr)
										downloadStatusIcon(status)
										<span> "{t[status]} {<b> dictionary.abbr}, {dictionary.name}"
								if no_dictionary_downloaded
									t["no_dictionary_downloaded"]

							else
								for language in languages
									<li key=language.language>
										<a.li [jc: start pl: 0px] dir="auto" @click=expandLanguageDownloads(language.language)>
											language.language
											<svg[ml:auto] src=ChevronDown [transform:rotate(180deg)]=(language.language == expandedLanguage) aria-label=t.open>

										if language.language == expandedLanguage
											<ul[o@off:0 m:0 0 1rem @off:-1.5rem 0 1.5rem transition-timing-function:quad h@off:0 of:hidden] dir="auto" ease>
												let no_translation_downloaded = yes
												for tr in language.translations when window.navigator.onLine || vault.downloaded_translations.includes(tr.short_name)
													no_translation_downloaded = no
													<button.downloadListItem @click=offlineTranslationAction(tr.short_name)>
														const status = translationDownloadStatus(tr.short_name)
														downloadStatusIcon(status)
														<span> "{t[status]} {<b> tr.short_name}, {tr.full_name}"

												if no_translation_downloaded
													t["no_translation_downloaded"]

					when 'support'
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2> t.support
							<a target="_blank" href="mailto:bpavlisinec@gmail.com" title=t.help>
								<svg src=Send aria-hidden=true>

						<article.rich-text.body>
							<h3> t.ycdtitnw
							<ul> for text in t.SUPPORT
								<li> <span innerHTML=text>
							<h3> t.thanks_to, ":"
							<ul> for text in contributors
								<li> <span innerHTML=text>

					when "notes"
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2> t.note, ', ', activities.selectedVersesTitle
							<button @click=activities.saveBookmark title=t.save>
								<svg src=Check [c@hover:lime4] aria-hidden=true>
						<article[o:0.8 fs:0.8em]>
							# display here the chosen verses
							let chosenVersesToIterate = activities.selectedParallel == reader.me ? reader.verses : parallelReader.verses
							for verse in chosenVersesToIterate
								<>
									if verse.pk in activities.selectedVersesPKs
										<span innerHTML=verse.text id=verse.pk>
										' '
						<mark-down>

					when "history"
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2> t.history
							<button @click=readingHistory.clear title=t.delete>
								<svg src=ICONS.TRASH aria-hidden=true>
						if readingHistory.history.length
							<ul.body>
								for history in readingHistory.history
									<li>
										css
											d:flex
											button
												fs:1.125rem lh:1
												p:.5rem .25rem
												c@hover:$acc-hover
												ta:start

										<button[fl:1 d:vbs g:.25rem] @click=(openHistoryEntry(history)) dir="auto">
											<span>
												getBookName(history.translation, history.book)
												' '
												history.chapter
												if history.verse
													':'
													history.verse
												' '
												history.translation
											<span[fs:.75rem o:.8]> format(new Date(history.date), 'PPpp')
										<button
											@click=openInParallel({
												translation: history.translation,
												book: history.book,
												chapter: history.chapter,
												verse: Number(history.verse)
											}) title=t.open_in_parallel>
												<svg src=SquareSplitHorizontal aria-hidden=yes>
						else
							<p[pt:1rem]> t.empty_history
						
					when "dictionary"
						<header.dictionary-header>
							<button.dictionary-obsidian @click=sendDictionaryToObsidian title="Obsidian">
								<svg src=Obsidian aria-hidden=yes>
							<h2> t.dictionary
							<button.dictionary-close [c@hover:red4] @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X aria-hidden=yes>

						<div.dictionary-search-row>
							<menu-popup.dictionary-picker bind=activities.show_dictionaries>
								<div.dictionary-picker-btn
									title=(dictionary.currentDictionaryName() or dictionary.currentDictionary)
									@click=(do activities.show_dictionaries = !activities.show_dictionaries)>
									dictionary.currentDictionary
									<svg src=ChevronDown aria-hidden=yes [transform:rotateX(180deg)]=activities.show_dictionaries>
								if activities.show_dictionaries
									<.popup-menu.dictionary-picker-menu [t:100% y@off:-2rem o@off:0] ease>
										for entry in dictionary.dictionaries
											<button .active-butt=(dictionary.currentDictionary==entry.abbr) @click=(do
													dictionary.currentDictionary = entry.abbr
													dictionary.loadDefinitions!
													)> entry.name
							<input#dictionarysearch.dictionary-query
								bind=dictionary.query minLength=2 type='text' placeholder=(t.search) aria-label=t.search
								[direction:{textDirection(dictionary.query)}]
								@keydown.enter=dictionary.loadDefinitions>
							<button.dictionary-icon-btn @click=dictionary.loadDefinitions title=t.search>
								<svg src=Search aria-hidden=yes>
							<button.dictionary-icon-btn @click=openDictionaryDownloads title=t.download>
								<svg src=Download aria-hidden=yes>

						if window.navigator.onLine
							<button.option-box.checkbox-parent [fs:0.85em mr:auto ws:pre padding-block:0.5rem]
								@click=(do settings.extended_dictionary_search = !settings.extended_dictionary_search) .checkbox-turned=settings.extended_dictionary_search>
								<span[ml:auto]> t.extended_search
								<.checkbox [margin-inline:1.5rem .5rem]> <span>
						if !dictionary.loading && dictionary.history.length
							<ul.body>
								for definition, index in dictionary.definitions when index < 64
									const expanded = dictionary.expandedTopic == definition.topic
									<li.definition id=definition.topic .expanded=expanded>
										<header @click=dictionary.expandDefinition(definition.topic)>
											<p>
												<b> definition.lexeme
												<span> ' · '
												<span> definition.pronunciation
												<span> ' · '
												<span> definition.transliteration
												<span> ' · '
												<b> definition.short_definition
												<span> ' · '
												<span> definition.topic
											<svg src=ChevronDown aria-hidden=yes [transform:rotateX(180deg)]=expanded>

										if expanded
											<div[p:16px 0px 32px @off:0 h:auto @off:0px overflow:hidden o@off:0] innerHTML=definition.definition ease>

						if dictionary.definitions.length == 0 and !dictionary.loading && dictionary.history.length
							<div.body[ai:center p:4rem 0 lh:1.6]>
								<p> t.nothing
								<p[pt:16px]> t.dictionary_help

					when 'font'
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2[fls:0]> t.setlocalfont
							<input[bdb@invalid:1px solid $acc-bgc] bind=fontsQuery minLength=2 type='text' placeholder=(t.search) aria-label=t.search>

						<ul.body>
							for font of theme.localFonts when font.toLowerCase().includes(fontsQuery.toLowerCase())
								<li
									[d:flex jc:space-between flw:wrap padding-block:0.5rem bxs@hover:inset 0 0 0.5rem $acc-bgc-hover rd:0.25rem cursor:pointer]
									role="button" @click=(do theme.fontFamily = font;theme.fontName = font)>
									<strong> font
									<span[font-family: {font}]> "The quick brown fox jumps over the lazy dog."

					when 'theme'
						<header>
							<button @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X [c@hover:red4] aria-hidden=true>
							<h2> t.theme
							<button @click=theme.applyCustomTheme title=t.save disabled=(Math.abs(customTheme.contrast) < 15)>
								<svg src=Check  aria-hidden=true>

						<article.body>
							css
								.range
									mb: 1rem

								label
									display: block
									lh: 1.5
									font-size: 0.85em
									font-weight: 500

								input
									w:100%
									accent-color: $acc
									-webkit-appearance: none
									appearance: none
									bgc: $acc-bgc @hover: $acc-bgc-hover
									outline: none
									mt:0.5rem
									rd:0.23rem
									h:.5rem

								input[type="range"]::-webkit-slider-thumb, input[type=range]::-moz-range-thumb
									-webkit-appearance: none
									height: 1.25rem
									width: 1.25rem
									border-radius: 23%
									background: $acc
									cursor: ew-resize

							<p.range>
								<label htmlFor="bgl"> t.backgroundLight
								<input id="bgl" type="range" min=0 max=1 step=.00125 bind=customTheme.darkness>
							<p.range>
								<label htmlFor="fgl"> t.foregroundLight
								<input id="fgl" type="range" min=0 max=1 step=.00125 bind=customTheme.lightness>
							<p[d:hcl g:1rem]>
								<color-picker color=customTheme.color @change=customTheme.setColor>
								t.contrast
								<span[c:{customTheme.contrastRateColor}]>
									customTheme.contrast

							<div [mt:.5rem]>
								css
									pos:{parallelReader.enabled ? 'relative' : 'static'}
									ff:{theme.fontFamily}
									fs:{theme.fontSize}px
									lh:{theme.lineHeight}
									fw:{theme.fontWeight}
									ta:{theme.align}
									fl:1 p:1.5rem rd:0.5rem
									bgc:{customTheme.background}
									c:{customTheme.foreground}

									--acc:{customTheme.acc}
									--acc-hover:{customTheme.accHover}
									--acc-bgc:{customTheme.accBgc}
									--acc-bgc-hover:{customTheme.accBgcHover}


								for verse, verse_index in reader.verses
									let bookmark = reader.getBookmark(verse.pk, 'bookmarks')
									let superStyle = "padding-bottom:{0.8 * theme.lineHeight}em;padding-top:{theme.lineHeight - 1}em;"

									if settings.verse_number
										unless settings.verse_break
											<span> ' '
										<a[fs:0.68em c:$acc @hover:$acc-hover bgc@hover:$acc-bgc-hover vertical-align:super ws:pre rd:0.25rem] dir="ltr" style=superStyle> '\u2007\u2007\u2007' + verse.verse + "\u2007"
									else
										<span> ' '
									<span innerHTML=verse.text
											tabIndex=0
											[background-image: {reader.getHighlight(verse.pk)}]
										>
									if bookmark and not reader.nextVerseHasTheSameBookmark(verse_index) and (bookmark.collection || bookmark.note)
										<note-tooltip style=superStyle parallelMode=parallelReader.enabled bookmark=bookmark containerWidth=self.clientWidth containerHeight=self.clientHeight>
											<svg src=Bookmark>
												<title> bookmark.collection + ': ' + bookmark.note

									if verse.comment and settings.verse_commentary
										<note-tooltip style=superStyle parallelMode=parallelReader.enabled bookmark=verse.comment containerWidth=self.clientWidth containerHeight=self.clientHeight>
											<span[c:$acc @hover:$acc-hover]> '†'

									if settings.verse_break
										<br>
										unless settings.verse_number
											<span.ws> '	'

					else	# MAIN SEARCH
						<header#search-header [pos:relative]>
							<button.focusable[c@hover:red4] @click=activities.cleanUp title=t.close>
								<svg src=ICONS.X aria-hidden=yes>

							<input id="generalsearch"
								[direction:{textDirection(search.query)}]
								minLength=3 type='text' placeholder=(t.bible_search + ', ' + reader.translation) aria-label=t.bible_search
								bind=search.query @keydown.enter=search.run>

							if search.suggestions.books..length or search.suggestions.translations..length
								<ul.suggestions>
									for book in search.suggestions.books
										<li>
											<p.li.focusable tabIndex="0"
												@keydown.enter=openSuggestedBook(book.bookid)
												@click=openSuggestedBook(book.bookid)
												> search.getSuggestionText(book)
											<button.focusable [ml:4px]
												@click=openSuggestedBookInParallel(book.bookid)
												@keydown.enter=openSuggestedBookInParallel(book.bookid) title=t.open_in_parallel>
												<svg src=SquareSplitHorizontal aria-hidden=yes>

									for translation in search.suggestions.translations
										<li>
											<p.li.focusable [display: flex] tabIndex="0" @click=changeTranslation(translation.short_name) @keydown.enter=changeTranslation(translation.short_name)>
												<span>
													<b> translation.short_name
													', '
													translation.full_name
											<button.focusable [ml:4px]
												@click=openTranslationInParallel(translation.short_name)
												@keydown.enter=openTranslationInParallel(translation.short_name) title=t.open_in_parallel>
												<svg src=SquareSplitHorizontal aria-hidden=yes>

							if window.navigator.onLine
								<button.focusable title=t.match_case [o:0.5]=!search.match_case @click=(search.match_case = !search.match_case)>
									<svg src=CaseSensitive aria-hidden=yes>
								<button.focusable title=t.match_whole [o:0.5]=!search.match_whole @click=(search.match_whole = !search.match_whole)>
									<svg src=WholeWord aria-hidden=yes>

							<button.focusable @click=search.run title=t.close>
								<svg src=Search aria-hidden=yes>

							if search.results.length
								<menu-popup bind=activities.show_filters>
									<button
										@click=(do activities.show_filters = !activities.show_filters)
										title=t.addFilter [c:$acc-hover]=(activities.show_filters || search.filter) ease>
										<svg src=Filter aria-hidden=yes>

									if activities.show_filters
										<.popup-menu [t:0 y@off:-2rem o@off:0 mah:72vh @lt-sm:96vh of:auto] ease>
											<header[d:hcs bg:$bgc p:0 .5rem pos:sticky t:-.5rem zi:24]>
												<p[ws:nowrap mr:.5rem fs:0.8em fw:bold]> t.addFilter
												<button[c@hover:red4] @click=(activities.show_filters = no) title=t.close>
													<svg src=ICONS.X aria-hidden=yes>

											if search.filter
												<button[w:100% p:0.5rem] @click=search.dropFilter> t.drop_filter

											<button[w:100% p:0.5rem ta:left] @click=search.addFilter("ot")> t.ot
											<button[w:100% p:0.5rem ta:left] @click=search.addFilter("nt")> t.nt

											for book in reader.books
												<button[w:100% p:0.5rem] .selected=(search.filter==book.bookid) [o:.5]=(!search.resultBooks.includes(book.bookid)) dir="auto" @click=search.addFilter(book.bookid)> book.name

						if search.currentQuery
							<p[o:0.75]> search.currentQuery, ': ', search.exactMatchesCount, ' / ',  search.total, ' ', t.totalyresultsofsearch
							<ul.body id="search-results">
								for verse, key in search.results
									<li>
										<text-as-html[fs:1.2rem cursor:pointer c@hover:$acc-hover] data=verse innerHTML=verse.text>
										<header[margin-block:0.25rem 1rem o:.75 @hover:1]>
											<span[margin-inline-start:auto]> getBookName(reader.translation, verse.book), ' '
											<span> verse.chapter, ':'
											<span> verse.verse
											<button @click=activities.copyToClipboardFromSearch(verse) title=t.copy>
												<svg src=Copy>
											<button
												@click=openVerseInParallel({
													book:verse.book,
													chapter:verse.chapter,
													verse:verse.verse}) title=t.open_in_parallel>
												<svg src=SquareSplitHorizontal aria-hidden=yes>
							
							if search.pages > 1 then <menu>
								<li[pos:sticky l:0 bgc:$bgc]> <button @click=search.goToPage(search.page - 1) disabled=(search.page==1) title=t.prev>
									<svg src=ChevronLeft aria-hidde-yes>
								
								for page in [1 .. search.pages]
									<li key="page-{page}">
										<button @click=search.goToPage(page) .active-page=(search.page==page)> page

								<li[pos:sticky r:0 bgc:$bgc]> <button @click=search.goToPage(search.page + 1) disabled=(search.page==search.pages) title=t.next>
									<svg src=ChevronRight aria-hidde-yes>
							
							unless search.results.length
								<div[display:vcc padding-block:4rem]>
									<p> t.nothing
							if search.filter
								<div[pt:0.5rem d:hcs]>
									t.filter_name + ' ' + getBookName(reader.translation, search.filter)
									<button.stdbtn @click=search.dropFilter> t.drop_filter

	css
		header
			d:hcc
			g:0.5rem

			button, a
				bgc:transparent c:inherit @hover:$acc-hover
				min-width:2rem w:2rem cursor:pointer
				d:flex fls:0
				o@disabled:0.5

			h2
				text-align: center
				margin: auto
				-webkit-line-clamp: 2
				overflow: hidden
				display: -webkit-box
				-webkit-box-orient: vertical
				fs:1em

			input
				w:100% bg:transparent font:inherit c:inherit
				p:0 0.5em fs:1.2em min-width:8rem
				bd:none bdb@invalid:1px solid $acc-bgc bxs:none
				lh:2rem

			svg
				min-inline-size: 1.5rem
				min-block-size: 1.5rem

		header.dictionary-header
			d:grid
			grid-template-columns: 2rem 1fr 2rem
			ai:center
			g:0.5rem
			min-height: 2.125rem

			h2
				m:0
				p:0
				ta:center
				fs:1.05em
				fw:700
				lh:1.2
				white-space:nowrap
				display:block
				overflow:visible
				-webkit-line-clamp: unset

			.dictionary-close
				justify-self:end

			.dictionary-obsidian
				justify-self:start
				c:inherit @hover:$acc-hover
				d:flex
				ai:center
				jc:center

			.dictionary-obsidian svg
				fill: currentColor
				c: inherit

		.dictionary-search-row
			d:flex
			ai:center
			g:0.5rem
			w:100%
			min-width: 0
			mt:0
			padding-block: 1.25rem
			pos:relative

		.dictionary-picker
			flex: 0 0 auto
			pos:static

		.dictionary-picker-btn
			d:inline-flex
			ai:center
			jc:center
			g:0.25rem
			box-sizing: border-box
			h: 2.125rem
			min-height: 2.125rem
			min-width: unset
			w:auto
			max-width: 9rem
			p:0 0.65rem
			rd:0.35rem
			bd:1px solid $acc-bgc-hover
			bgc:$acc-bgc @hover:$acc-bgc-hover
			tt:uppercase
			fw:600
			fs:0.8em
			lh:1
			c:inherit @hover:$acc-hover
			cursor:pointer
			overflow: hidden

			svg
				w:1.05em
				h:1.05em
				min-inline-size: 1.05em
				min-block-size: 1.05em
				flex-shrink: 0

		.dictionary-picker-menu, .dictionary-picker .popup-menu
			l: 0
			r: 0
			w: auto
			min-width: 0
			max-width: 100%
			box-sizing: border-box
			of: auto
			mah: min(70vh, 24rem)
			mah@lt-sm: min(60vh, 18rem)

			button
				w: 100%
				min-width: 0
				white-space: normal
				overflow-wrap: anywhere
				padding: 0.85rem 1rem
				padding@lt-sm: 0.75rem 0.85rem
				lh: 1.35
				fs: 0.95em
				fs@lt-sm: 0.9em

		.dictionary-query
			flex: 1 1 auto
			min-width: 0
			w:auto
			h:2.125rem
			box-sizing: border-box
			p:0 0.65rem
			fs:1.05em
			lh:2.125rem
			bg:transparent
			font: inherit
			c: inherit
			bgc:$acc-bgc @focus:$acc-bgc-hover
			bd:1px solid $acc-bgc-hover
			rd:0.35rem
			bxs:none @focus:0 0 0 1px $acc

		.dictionary-icon-btn
			bgc:transparent
			c:inherit @hover:$acc-hover
			min-width:2rem
			w:2rem
			cursor:pointer
			d:flex
			ai:center
			jc:center
			fls:0

			svg
				min-inline-size: 1.5rem
				min-block-size: 1.5rem

		.body
			overflow-y: auto
			-webkit-overflow-scrolling: touch
			scroll-behavior: smooth
			d:vts
			fl:1
			h:100%

		.definition
			overflow:hidden
			lh:1.6
			fls:0

			header
				d:flex
				ai:center
				pos:sticky
				p:.5rem .5rem .5rem 0
				cursor:pointer
				t:0px
				m:0
				bg:$bg
				bdt:1px solid $acc-bgc

			p
				ws:break-spaces

			svg
				transform:$svg-transform
				ml:auto

		.suggestions
			d:vflex p:.5rem
			max-height:calc(72vh - 50px)
			pos:absolute t:100% r:0 l:0 zi:1
			of:auto bg:$bgc o:0
			border:1px solid $acc-bgc-hover bdt:none rdbl:.5rem rdbr:.5rem
			visibility:hidden

			li
				d:hcs

		#search-header@focin
			.suggestions
				visibility:visible
				o:1
		
		#gotobook-header@focin
			.suggestions
				visibility:visible
				o:1
		
		.gotobook-go-btn
			min-width: 2rem
			width: 2rem
			height: 2rem
			font-size: 1rem
			font-weight: 600
			display: flex
			align-items: center
			justify-content: center
		
		menu # search pagination
			d:flex margin-inline:auto
			max-inline-size:100%
			padding-block:0.25rem
			pos:relative
			ofx:auto fls:0

			li
				list-style-type:none
				cursor:pointer

				button
					d:hcc
					c@hover:$acc-hover
					bgc:transparent @hover:$acc-bgc
					s:2rem rd:.25rem lh:1

				button@disabled
					o:0.5 bgc@hover:transparent c@hover:inherit

		.active-page
			bgc:$acc-bgc-hover c:$acc-hover

		.li
			d:hcs
			p:0.5rem c@hover:$acc-hover
			cursor:pointer
			width:100%

		.li.selected
			bgc:$acc-bgc-hover
			c:$acc
			fw:600
			bd:1px solid $acc

		.focusable
			rd:0.5rem

			@focus, @focin
				outline:1px solid $acc-hover
				outline-offset:-1px

		.rich-text
			text-indent: 2rem

			h3
				margin-block: 2rem 0.75rem
				font-weight: 500
				color: $acc

			ul
				margin-block: 1rem
				padding-left: 2rem

			li
				margin: 12px
				text-indent: 0
				list-style: hebrew

			#iosinstall a, a
				color: inherit
				background-image: linear-gradient(var(--c) 0px, var(--c) 100%)

			p
				line-height: 2
		
		.downloadListItem
			d:hcl g:.5rem
			ta:start
			py:.5rem pl:.5rem
			bgc:transparent @hover:$acc-bgc-hover
			c:$c @hover:$acc-hover
			rd:.5rem w:100% font:inherit

			svg
				w:1.5rem h:1.5rem fls:0
