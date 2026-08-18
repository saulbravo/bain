import Copy from 'lucide-static/icons/copy.svg'
import Obsidian from '../icons/obsidian.svg'
import Link from 'lucide-static/icons/link.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import ChevronUp from 'lucide-static/icons/chevron-up.svg'
import Dices from 'lucide-static/icons/dices.svg'
import Share from 'lucide-static/icons/share.svg'
import Split from 'lucide-static/icons/split.svg'
import NotebookPen from 'lucide-static/icons/notebook-pen.svg'
import Bookmark from 'lucide-static/icons/bookmark.svg'
import Facebook from 'lucide-static/icons/facebook.svg'
import Eraser from 'lucide-static/icons/eraser.svg'
import Trash2 from 'lucide-static/icons/trash-2.svg'
import BookOpenText from 'lucide-static/icons/book-open-text.svg'
import Plus from 'lucide-static/icons/plus.svg'
import X from 'lucide-static/icons/x.svg'

import * as ICONS from 'imba-phosphor-icons'
import { hasTouchEvents } from '../constants'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'

const DEFAULT_Y = 32

tag verse-actions < section
	#isSliding = null
	#dy = DEFAULT_Y
	categoriesSearch = ''

	def close
		# should await for the transition-duration property update to achieve smoothness
		#dy = DEFAULT_Y
		activities.isVerseActionsMinimized = no
		imba.commit!.then do
			activities.cleanUp!

	def touchHandler event
		#dy = Math.max(event.y - event.y0, -DEFAULT_Y) + DEFAULT_Y
		#isSliding = null
		event.stopPropagation!

		if event.phase == "ended"
			if #dy > DEFAULT_Y * 2
				event.preventDefault()
				close!
			#isSliding = null
			#dy = DEFAULT_Y


	get transitionDuration
		return #dy == DEFAULT_Y ? '0.5s' : '0s'


	def byteCount s\string
		window.encodeURI(s).split(/%..|./).length - 1


	get canShareViaTelegram
		return byteCount("https://t.me/share/url?url={window.encodeURIComponent("https://bolls.life" + '/'+ activities.copyObject.translation + '/' + activities.copyObject.book + '/' + activities.copyObject.chapter + '/' + activities.versesRange(activities.copyObject.verses) + '/')}&text={window.encodeURIComponent('«' + activities.copyObject.text + '»\n\n' + activities.copyObject.title + ' ' + activities.copyObject.translation)}") < 4096

	def telegramSharing
		const text = '«' + activities.copyObject.text + '»\n\n' + activities.copyObject.title + ' ' + activities.copyObject.translation
		const url = "https://bolls.life" + '/'+ activities.copyObject.translation + '/' + activities.copyObject.book + '/' + activities.copyObject.chapter + '/' + activities.versesRange(activities.copyObject.verses) + '/'
		const link = "https://t.me/share/url?url={window.encodeURIComponent(url)}&text={window.encodeURIComponent(text)}"
		if byteCount(link) < 4096
			window.open(link, '_blank')

	get sharedText
		const text = '«' + activities.copyObject.text + '»\n\n' + activities.copyObject.title + ' ' + activities.copyObject.translation + "https://bolls.life" + '/'+ activities.copyObject.translation + '/' + activities.copyObject.book + '/' + activities.copyObject.chapter + '/' + activities.versesRange(activities.copyObject.verses) + '/'
		return text

	get canMakeTweet
		return sharedText.length < 281

	def makeTweet
		window.open("https://twitter.com/intent/tweet?text={window.encodeURIComponent(sharedText)}", '_blank')
		activities.cleanUp!

	def shareViaFB
		window.open("https://www.facebook.com/sharer.php?u=https://bolls.life/" + activities.copyObject.translation + '/' + activities.copyObject.book + '/' + activities.copyObject.chapter + '/' + activities.versesRange(activities.copyObject.verses) + '/', '_blank')
		activities.cleanUp!

	def shareViaWhatsApp
		window.open("https://api.whatsapp.com/send?text={window.encodeURIComponent(sharedText)}", '_blank')
		activities.cleanUp!

	def deleteBookmark
		if activities.selectedParallel == 'main'
			reader.deleteBookmark activities.selectedVersesPKs
		else
			parallelReader.deleteBookmark activities.selectedVersesPKs

	get selectionHasBookmark
		if activities.selectedParallel == 'main'
			return reader.selectionHasBookmark
		return parallelReader.selectionHasBookmark

	def clearAllHighlights e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if hasTouchEvents or window.confirm("Clear all highlights in this chapter?")
			if activities.selectedParallel == 'main'
				reader.clearAllChapterHighlights!
			else
				parallelReader.clearAllChapterHighlights!

	def showAddNewCategory
		activities.show_add_bookmark = yes
		imba.commit!.then do $newcategoryinput.focus()

	<self [y:{activities.isVerseActionsMinimized ? (window.innerWidth < 1024 ? 'calc(100% - 2.75rem)' : '100%') : #dy + 'px'} @off:100% o@off:0 transition-duration:{transitionDuration}] ease
		.is-minimized=activities.isVerseActionsMinimized
		@touch.fit(self)=touchHandler
	>
		<div.control-tabs>
			<button.tab.minimize @click=(activities.isVerseActionsMinimized = !activities.isVerseActionsMinimized) title=(activities.isVerseActionsMinimized ? "Restore" : "Minimize")>
				<svg src=(activities.isVerseActionsMinimized ? ChevronUp : ChevronDown)>
			<button.tab.close @click=close title="Close">
				<svg src=X>
		<svg.chevron src=ChevronDown @click=close>
		<header>
			<span role="button" @click=activities.copyTextToClipboard(activities.selectedVersesTitle)>
				activities.selectedVersesTitle

		<ul.color-options>
			<li[d:inline-flex ai:center jc:center cursor:pointer c@hover:$acc m:0 0.25rem]>
				<svg src=Dices width="2rem" height="2rem" role="button" aria-label=t.random
				@click=(do
					let randomColor = activities.randomColor
					activities.highlight_color = randomColor
					if activities.selectedVersesPKs.length > 0
						if activities.selectedParallel == 'main'
							reader.applyHighlightPreview(activities.selectedVersesPKs, randomColor)
							reader.saveBookmark!
						else
							parallelReader.applyHighlightPreview(activities.selectedVersesPKs, randomColor)
							parallelReader.saveBookmark!
						# Clear selection after applying highlight
						activities.selectedVerses = []
						activities.selectedVersesPKs = []
						activities.selectedParallel = undefined
						activities.activeVerseAction = undefined
						imba.commit!
				)>

			<li.color-option[scale:unset]>
				<color-picker[w:100%] color=activities.highlight_color @change=activities.setHighlightColor>

			for color in activities.highlightColors
				<li.color-option [background:{color}] title=color role="button" aria-label=color
					.selected=(activities.highlight_color == color)
					@click.stop.prevent=activities.changeHighlightColor(color)>


		<menu>
			if reader.selectionHasBookmark or parallelReader.selectionHasBookmark
				<li>
					<button @click=deleteBookmark title=(t.delete or "Delete")>
						<svg src=Eraser aria-hidden=yes>
			<li>
				<button .copy-select-active=(activities.copySelectMode) @click=(do
					let wasOff = !activities.copySelectMode
					activities.copySelectMode = !activities.copySelectMode
					
					if !activities.copySelectMode
						# Turning OFF - clear selection for both readers
						activities.copySelectedVersesPKs = []
						activities.copySelectStartPK = 0
						activities.copySelectEndPK = 0
						activities.copySelectStartPKMain = 0
						activities.copySelectEndPKMain = 0
						activities.copySelectStartPKParallel = 0
						activities.copySelectEndPKParallel = 0
						activities.copySelectModeReader = null
					elif wasOff and activities.selectedVersesPKs.length > 0
						# Turning ON and there are selected verses - activate purple box
						let selectedPKs = activities.selectedVersesPKs
						if selectedPKs.length > 0
							# Determine which reader has these verses and update the selection box
							let targetReader = null
							let readerType = ''
							
							# First check selectedParallel
							if activities.selectedParallel == 'main'
								targetReader = reader
								readerType = 'main'
							elif activities.selectedParallel == parallelReader
								targetReader = parallelReader
								readerType = 'parallel'
							else
								# Try to determine which reader has these verses by checking PKs
								let hasMainVerses = reader.verses.some(do |v| return selectedPKs.includes(v.pk))
								let hasParallelVerses = parallelReader.verses.some(do |v| return selectedPKs.includes(v.pk))
								
								if hasMainVerses and !hasParallelVerses
									targetReader = reader
									readerType = 'main'
								elif hasParallelVerses and !hasMainVerses
									targetReader = parallelReader
									readerType = 'parallel'
								elif hasMainVerses and hasParallelVerses
									# Both have verses - prefer the one with more matches
									let mainCount = reader.verses.filter(do |v| return selectedPKs.includes(v.pk)).length
									let parallelCount = parallelReader.verses.filter(do |v| return selectedPKs.includes(v.pk)).length
									if parallelCount >= mainCount
										targetReader = parallelReader
										readerType = 'parallel'
									else
										targetReader = reader
										readerType = 'main'
							
							# Set the active reader and update the selection box
							if targetReader
								activities.copySelectModeReader = targetReader
								# Set per-reader PKs
								if readerType == 'main'
									activities.copySelectStartPKMain = selectedPKs[0]
									activities.copySelectEndPKMain = selectedPKs[selectedPKs.length - 1]
								else
									activities.copySelectStartPKParallel = selectedPKs[0]
									activities.copySelectEndPKParallel = selectedPKs[selectedPKs.length - 1]
								# Also set global PKs for backward compatibility
								activities.copySelectStartPK = selectedPKs[0]
								activities.copySelectEndPK = selectedPKs[selectedPKs.length - 1]
								targetReader.updateCopySelectRange!
					
					imba.commit!
				)>
					<svg src=Obsidian aria-hidden=yes title="Obsidian">
			<li>
				<button @click=activities.copyWithoutLink title=(t.copy or "Copy")>
					<svg src=Copy aria-hidden=yes>
			<li>
				<button @click=compare.load title=(t.compare or "Compare")>
					<svg src=Split aria-hidden=yes>
			<li>
				<menu-popup bind=activities.show_sharing>
					<button @click=(do activities.show_sharing = !activities.show_sharing) title=(t.share or "Share")>
						<svg src=Share aria-hidden=yes>
						if activities.show_sharing
							<.popup-menu [l:0 @lt-sm:0.5rem top:unset b:calc(100% + .25rem) y@off:2rem o@off:0 w:14rem] ease>
								<button @click=shareViaWhatsApp>
									<svg src=ICONS.WHATSAPP_LOGO aria-hidden=yes>
									"What's App"
								<button @click=shareViaFB>
									<svg src=Facebook aria-hidden=yes>
									"Facebook"
								if canMakeTweet then <button @click=makeTweet>
									<svg src=ICONS.X_LOGO aria-hidden=yes>
									"𝕏"
								if canShareViaTelegram then <button @click=telegramSharing>
									<svg src=ICONS.TELEGRAM_LOGO aria-hidden=yes>
									"Telegram"
								<button @click=activities.copyWithInternationalLink>
									<svg src=ICONS.TRANSLATE aria-hidden=yes>
									t.copy_international
								<button @click=(do()
										activities.copyWithLink(activities.copyObject)
										activities.cleanUp!
									)>
										<svg src=Link aria-hidden=yes>
										t.copy_with_link
			<li>
				<button.bookmark-toggle .applied=selectionHasBookmark @click=(do
					if selectionHasBookmark
						deleteBookmark!
						return
					activities.selectedCategories = []
					activities.note = ''
					# Bookmark only (no highlight): empty color so no background is applied
					activities.highlight_color = ''
					if activities.selectedParallel == 'main'
						reader.saveBookmark(yes)
					else
						parallelReader.saveBookmark(yes)
					activities.cleanUp!
				) title=(selectionHasBookmark ? (t.delete or "Remove bookmark") : (t.bookmark or "Bookmark"))>
					<svg src=Bookmark aria-hidden=yes>
			<li>
				<button @click=(do
					activities.activeVerseAction = 'commentary'
					imba.commit!
				) title=(t.verse_commentary or "Verse commentary")>
					<svg src=BookOpenText aria-hidden=yes>
			<li>
				<button @click.stop.prevent=clearAllHighlights role="button" aria-label="Clear all" title=(t.delete_all or "Clear All")>
					<svg src=Trash2 aria-hidden=yes>

	css
		pos:fixed b:0 l:0 r:0 zi:1100
		w:100% bgc:$bgc
		bdt:1px solid $acc-bgc
		ta:center
		d:vcc
		padding-block:1rem 2.5rem
		
		&.is-minimized
			bgc: transparent
			bdt: none
			pointer-events: none
			.control-tabs
				pointer-events: auto
			header, ul, menu
				o: 0

		.chevron
			pos:absolute
			top:-0.25rem
			scale-x: 2
			scale-y: 0.5
			d:none

		.control-tabs
			pos: absolute
			bottom: 100%
			right: 2rem
			d: flex
			gap: 0.5rem

		.tab
			bgc: $bgc
			bdt: 1.5px solid $acc-bgc
			bdl: 1.5px solid $acc-bgc
			bdr: 1.5px solid $acc-bgc
			rd: 1rem 1rem 0 0
			size: 4.5rem 2.5rem
			d: hcc
			p: 0
			c: $c
			cursor: pointer
			border-bottom: none
			transition: all 0.2s
			svg
				size: 1.75rem

		button
			fs:0.875rem

		header
			d:hcs
			g:0.5rem

			span
				cursor:copy

			button
				bgc:transparent @hover:$acc-bgc-hover
				bxs@hover: 0 0.5rem $acc-bgc-hover, 0 -0.5rem $acc-bgc-hover
				tt:uppercase fw:700
				c:$acc-hover @hover:$acc
				padding-inline:1rem m:0
				cursor:pointer

		.color-options
			white-space: nowrap
			padding-block: 1rem .5rem
			padding-inline: 0.5rem
			max-width: 100%
			d:flex
			flw:nowrap
			jc:center
			ai:center
			g:.5rem

		.color-option
			size:2rem
			border-radius: 23%
			cursor: pointer
			fls:0
			scale@hover: 1.2
			&.selected
				border: 3px solid $acc

		menu
			d:hcc
			pos:relative
			flw:wrap

		button
			display:hcc g:.25rem
			c:$c @hover:$acc
			bgc:transparent @hover:$acc-bgc-hover
			padding:0.75rem
			cursor:pointer
			rd:0.25rem

			svg
				size:1.5rem

		.popup-menu
			> button
				font:inherit
				p:0.75rem
				rd:0

		li
			list-style-type: none
			d:inline-block
		
		.applied
			c@important:$acc-hover
		
		.bookmark-toggle.applied
			svg
				fill: currentColor
				stroke: currentColor
		
		.copy-select-active
			c@important: #a855f7
			svg
				c@important: #a855f7
