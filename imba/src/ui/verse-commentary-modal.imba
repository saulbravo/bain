import activities from '../lib/Activities'
import API from '../lib/Api'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import theme from '../lib/Theme'
import { getBookName } from '../utils'
import { localizeCommentaryRefs, htmlToPlainText, splitCommentaryHtmlIntoBlocks } from '../utils/cbaBooks'
import X from 'lucide-static/icons/x.svg'
import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import ChevronRight from 'lucide-static/icons/chevron-right.svg'
import Obsidian from '../icons/obsidian.svg'
import Split from 'lucide-static/icons/split.svg'

tag verse-commentary-modal
	loading = no
	error = ''
	commentaryHtml = ''
	commentaryBlocks = []
	obsidianMode = no
	compareMode = no
	exportStartIdx = 0
	exportEndIdx = 0
	obsidianBoxTop = 0
	obsidianBoxHeight = 0
	obsidianBoxVisible = no
	currentVerse = 0
	lastLoadKey = ''
	#onObsidianScroll = null
	#obsidianBlockClicks = []
	obsidianDragging = no
	obsidianDragHandle = ''
	lastDragBlockIdx = -1
	obsidianDragRAF = null
	#obsidianBlockClickLock = no

	get currentReader
		if activities.selectedParallel == 'main'
			return reader
		if activities.selectedParallel and activities.selectedParallel != 'main'
			return parallelReader
		return reader

	get bookName
		return getBookName(currentReader.translation, currentReader.book)

	commentaryLineHeight = 1.5

	get commentaryReference
		return "{bookName} {currentReader.chapter}:{currentVerse}"

	get commentaryTitle
		return "Comentario Bíblico Adventista"

	get contentStyle
		return "--cmt-pt:{commentaryLineHeight - 1}em;--cmt-pb:{0.8 * commentaryLineHeight}em"

	def applyCommentaryTypography
		let content = getContentEl!
		if !content
			return
		content.style.setProperty('--cmt-pt', "{commentaryLineHeight - 1}em")
		content.style.setProperty('--cmt-pb', "{0.8 * commentaryLineHeight}em")
		let reading = content.querySelector('.commentary-text')
		if !reading
			return
		reading.style.fontFamily = theme.fontFamily
		reading.style.fontSize = "{theme.fontSize}px"
		reading.style.lineHeight = String(commentaryLineHeight)
		reading.style.fontWeight = String(theme.fontWeight)
		let paras = reading.querySelectorAll('p')
		if !paras or paras.length == 0
			return
		let padTop = "{commentaryLineHeight - 1}em"
		let padBottom = "{0.8 * commentaryLineHeight}em"
		for i in [0 .. paras.length - 1]
			let p = paras[i]
			p.style.margin = '0'
			p.style.paddingTop = i > 0 ? padTop : '0'
			p.style.paddingBottom = padBottom
			p.style.lineHeight = String(commentaryLineHeight)

	def getChapterVerseNumbers
		let nums = []
		let chapterVerses = currentReader.verses or []
		for v in chapterVerses
			nums.push(Number(v.verse))
		nums.sort(do |a, b| return a - b)
		let unique = []
		for n in nums
			unless unique.includes(n)
				unique.push(n)
		return unique

	def getSelectedVerseNumbers
		let nums = []
		let chapterVerses = currentReader.verses or []
		if activities.selectedVersesPKs and activities.selectedVersesPKs.length
			for v in chapterVerses
				if activities.selectedVersesPKs.includes(v.pk)
					nums.push(Number(v.verse))
		elif activities.selectedVerses and activities.selectedVerses.length
			let valid = chapterVerses.map(do |item| return Number(item.verse))
			for n in activities.selectedVerses
				let verseNum = Number(n)
				if valid.includes(verseNum)
					nums.push(verseNum)
		nums.sort(do |a, b| return a - b)
		let unique = []
		for n in nums
			unless unique.includes(n)
				unique.push(n)
		return unique

	def getVerseNumbers
		return getChapterVerseNumbers!

	def clampCurrentVerse
		let nums = getChapterVerseNumbers!
		if nums.length == 0
			currentVerse = 0
			return
		if currentVerse <= 0 or !nums.includes(currentVerse)
			let selected = getSelectedVerseNumbers!
			if selected.length
				currentVerse = selected[selected.length - 1]
			else
				currentVerse = nums[0]

	def resetExportRange
		exportStartIdx = 0
		exportEndIdx = 0

	def unmount
		teardownObsidianUI!

	def close
		stopObsidianDragListeners!
		teardownObsidianUI!
		obsidianMode = no
		compareMode = no
		resetExportRange!
		lastLoadKey = ''
		activities.activeVerseAction = 'options'
		imba.commit!

	def toggleCompareMode
		compareMode = !compareMode
		imba.commit!

	def toggleObsidianMode
		obsidianMode = !obsidianMode
		if obsidianMode
			resetExportRange!
			imba.commit!
			imba.commit!.then do
				applyCommentaryTypography!
				buildObsidianUI!
		else
			stopObsidianDragListeners!
			teardownObsidianUI!
			imba.commit!

	def ensureObsidianDragBindings
		unless #boundObsidianMove
			#boundObsidianMove = handleObsidianDrag.bind(self)
		unless #boundObsidianEnd
			#boundObsidianEnd = handleObsidianDragEnd.bind(self)

	def stopObsidianDragListeners
		document.documentElement.removeAttribute('data-commentary-obsidian-dragging')
		if #boundObsidianMove
			document.removeEventListener('mousemove', #boundObsidianMove)
			document.removeEventListener('touchmove', #boundObsidianMove)
			document.removeEventListener('pointermove', #boundObsidianMove)
		if #boundObsidianEnd
			document.removeEventListener('mouseup', #boundObsidianEnd)
			document.removeEventListener('touchend', #boundObsidianEnd)
			document.removeEventListener('touchcancel', #boundObsidianEnd)
			document.removeEventListener('pointerup', #boundObsidianEnd)
			document.removeEventListener('pointercancel', #boundObsidianEnd)
		if obsidianDragRAF
			window.cancelAnimationFrame(obsidianDragRAF)
			obsidianDragRAF = null
		obsidianDragging = no
		obsidianDragHandle = ''
		lastDragBlockIdx = -1

	def startObsidianDrag handle\string, e
		ensureObsidianDragBindings!
		unless obsidianMode or !#boundObsidianMove or !#boundObsidianEnd
			return
		if !e
			return
		e.preventDefault()
		e.stopPropagation()
		obsidianDragging = yes
		obsidianDragHandle = handle
		lastDragBlockIdx = -1
		if e.target and e.target.setPointerCapture and e.pointerId != undefined
			try
				e.target.setPointerCapture(e.pointerId)
			catch err
				pass
		document.addEventListener('mousemove', #boundObsidianMove)
		document.addEventListener('mouseup', #boundObsidianEnd)
		document.addEventListener('touchmove', #boundObsidianMove, { passive: no })
		document.addEventListener('touchend', #boundObsidianEnd)
		document.addEventListener('touchcancel', #boundObsidianEnd)
		document.addEventListener('pointermove', #boundObsidianMove)
		document.addEventListener('pointerup', #boundObsidianEnd)
		document.addEventListener('pointercancel', #boundObsidianEnd)
		handleObsidianDrag(e)

	def findBlockIndexFromElement element
		let el = element
		let depth = 0
		while el and depth < 20
			if el.dataset and el.dataset.blockIdx != undefined and el.dataset.blockIdx != ''
				let idx = parseInt(el.dataset.blockIdx, 10)
				if !isNaN(idx)
					return idx
			el = el.parentElement
			depth++
		return -1

	def getObsidianBlockElements
		let reading = getContentEl! and getContentEl!.querySelector('.commentary-text')
		if !reading
			return []
		return reading.querySelectorAll('[data-block-idx]')

	def findBlockIndexFromY clientY\number
		let nodes = getObsidianBlockElements!
		if !nodes or nodes.length == 0
			return -1
		for i in [0 .. nodes.length - 1]
			let rect = nodes[i].getBoundingClientRect()
			let midY = rect.top + (rect.height / 2)
			if clientY <= midY
				let idx = parseInt(nodes[i].dataset.blockIdx, 10)
				if !isNaN(idx)
					return idx
		let last = nodes[nodes.length - 1]
		let lastIdx = parseInt(last.dataset.blockIdx, 10)
		return isNaN(lastIdx) ? nodes.length - 1 : lastIdx

	def handleObsidianDrag e
		if !obsidianDragging or !obsidianMode or !e or typeof e.type != 'string'
			return
		e.preventDefault()
		e.stopPropagation()
		document.documentElement.setAttribute('data-commentary-obsidian-dragging', 'true')
		if obsidianDragRAF
			window.cancelAnimationFrame(obsidianDragRAF)
		let touch = e.type.startsWith('touch') ? (e.touches and e.touches.length > 0 ? e.touches[0] : (e.changedTouches and e.changedTouches[0] ? e.changedTouches[0] : null)) : null
		let clientX = touch ? touch.clientX : e.clientX
		let clientY = touch ? touch.clientY : e.clientY
		obsidianDragRAF = window.requestAnimationFrame(do
			let hit = document.elementFromPoint(clientX, clientY)
			let idx = findBlockIndexFromElement(hit)
			if idx < 0
				idx = findBlockIndexFromY(clientY)
			if idx < 0
				obsidianDragRAF = null
				return
			if idx != lastDragBlockIdx
				lastDragBlockIdx = idx
				if obsidianDragHandle == 'top'
					exportStartIdx = Math.min(idx, exportEndIdx)
				elif obsidianDragHandle == 'bottom'
					exportEndIdx = Math.max(idx, exportStartIdx)
			updateObsidianBox!
			obsidianDragRAF = null
		)

	def handleObsidianDragEnd e
		stopObsidianDragListeners!

	def handleObsidianBlockClick idx\number, e
		if !obsidianMode or obsidianDragging or #obsidianBlockClickLock
			return
		if !e
			return
		e.preventDefault()
		e.stopPropagation()
		exportStartIdx = idx
		exportEndIdx = idx
		updateObsidianBox!

	def updateObsidianBox
		unless obsidianMode
			obsidianBoxVisible = no
			return
		window.requestAnimationFrame do
			let contentEl = getContentEl!
			let readingEl = contentEl and contentEl.querySelector('.commentary-text')
			if !contentEl or !readingEl or commentaryBlocks.length == 0
				obsidianBoxVisible = no
				imba.commit!
				return
			let startEl = readingEl.querySelector("[data-block-idx=\"{exportStartIdx}\"]")
			let endEl = readingEl.querySelector("[data-block-idx=\"{exportEndIdx}\"]")
			if !startEl or !endEl
				obsidianBoxVisible = no
				imba.commit!
				return
			let contentRect = contentEl.getBoundingClientRect()
			let startRect = startEl.getBoundingClientRect()
			let endRect = endEl.getBoundingClientRect()
			let top = startRect.top - contentRect.top + contentEl.scrollTop - 6
			let bottom = endRect.bottom - contentRect.top + contentEl.scrollTop + 6
			obsidianBoxTop = Math.max(0, top)
			obsidianBoxHeight = Math.max(24, bottom - top)
			obsidianBoxVisible = yes
			imba.commit!

	def getObsidianExportSections
		let start = Math.min(exportStartIdx, exportEndIdx)
		let end = Math.max(exportStartIdx, exportEndIdx)
		let sections = []
		let reading = getContentEl! and getContentEl!.querySelector('.commentary-text')
		for i in [start .. end]
			let text = ''
			let block = commentaryBlocks[i]
			if block and block.text
				text = String(block.text).trim()
			if !text and reading
				let el = reading.querySelector("[data-block-idx=\"{i}\"]")
				if el
					text = String(el.textContent or '').trim()
			if text
				sections.push({
					reference: String(commentaryReference)
					verse: Number(currentVerse)
					text: text
				})
		return sections

	def postObsidianSelection message
		let messageData = {
			type: String(message.type)
			sections: Array.from(message.sections or [])
			commentaryTitle: String(message.commentaryTitle or commentaryTitle)
			reference: String(message.reference or commentaryReference)
			translation: String(message.translation or '')
			book: String(message.book or '')
			chapter: Number(message.chapter or 1)
			bookId: Number(message.bookId or 1)
		}
		let sent = no
		if window.parent and window.parent != window
			try
				window.parent.postMessage(messageData, '*')
				sent = yes
			catch err
				sent = no
		if !sent and window.parent and window.parent != window
			try
				let jsonMessage = JSON.parse(JSON.stringify(messageData))
				window.parent.postMessage(jsonMessage, '*')
			catch fallbackError
				pass

	def sendCommentaryToObsidian
		unless obsidianMode
			return
		let sections = getObsidianExportSections!
		if sections.length == 0
			return
		postObsidianSelection({
			type: 'bible-commentary-selection'
			sections: sections
			commentaryTitle: String(commentaryTitle)
			reference: String(commentaryReference)
			translation: String(currentReader.translation or '')
			book: String(bookName or '')
			chapter: Number(currentReader.chapter or 1)
			bookId: Number(currentReader.book or 1)
		})

	def getContentEl
		return self.querySelector('.content')

	def clearCommentaryObsidianAnnotations
		if #obsidianBlockClicks and #obsidianBlockClicks.length
			for item in #obsidianBlockClicks
				if item.el and item.handler
					item.el.removeEventListener('click', item.handler)
					item.el.removeAttribute('data-block-idx')
					item.el.style.cursor = ''
			#obsidianBlockClicks = []

	def annotateCommentaryBlocksForObsidian
		clearCommentaryObsidianAnnotations!
		let reading = getContentEl! and getContentEl!.querySelector('.commentary-text')
		if !reading
			return no
		let paras = reading.querySelectorAll('p')
		if !paras or paras.length == 0
			return no
		let modal = self
		let blockIdx = 0
		for i in [0 .. paras.length - 1]
			let p = paras[i]
			let text = String(p.textContent or '').trim()
			if !text
				continue
			p.dataset.blockIdx = String(blockIdx)
			p.style.cursor = 'pointer'
			let idx = blockIdx
			let handler = do |e|
				modal.handleObsidianBlockClick(idx, e)
			p.addEventListener('click', handler)
			#obsidianBlockClicks.push({ el: p, handler: handler })
			blockIdx++
		return blockIdx > 0

	def teardownObsidianUI
		stopObsidianDragListeners!
		if #onObsidianScroll
			let contentEl = getContentEl!
			if contentEl
				contentEl.removeEventListener('scroll', #onObsidianScroll)
		obsidianBoxVisible = no
		clearCommentaryObsidianAnnotations!
		let contentEl = getContentEl!
		if contentEl
			contentEl.classList.remove('commentary-obsidian-active')

	def buildObsidianUI
		teardownObsidianUI!
		let contentEl = getContentEl!
		if !contentEl or commentaryBlocks.length == 0
			return
		unless annotateCommentaryBlocksForObsidian!
			return
		contentEl.classList.add('commentary-obsidian-active')
		unless #onObsidianScroll
			#onObsidianScroll = updateObsidianBox.bind(self)
		contentEl.addEventListener('scroll', #onObsidianScroll, { passive: yes })
		exportStartIdx = 0
		exportEndIdx = 0
		updateObsidianBox!

	def stepVerse delta\number
		let nums = getVerseNumbers!
		return if nums.length == 0
		let idx = nums.indexOf(currentVerse)
		if idx < 0
			idx = 0
		let next = Math.max(0, Math.min(nums.length - 1, idx + delta))
		currentVerse = nums[next]
		teardownObsidianUI!
		obsidianMode = no
		compareMode = no
		resetExportRange!
		imba.commit!
		loadCommentary!

	get canGoPrev
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(currentVerse)
		return idx > 0

	get canGoNext
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(currentVerse)
		return idx >= 0 and idx < nums.length - 1

	def loadCommentary
		clampCurrentVerse!
		return if currentVerse <= 0
		let key = "{currentReader.translation}:{currentReader.book}:{currentReader.chapter}:{currentVerse}"
		return if key == lastLoadKey
		lastLoadKey = key
		loading = yes
		error = ''
		commentaryHtml = ''
		commentaryBlocks = []
		teardownObsidianUI!
		obsidianMode = no
		compareMode = no
		resetExportRange!
		imba.commit!
		try
			let payload = await API.getJson("/get-cba-commentary/{currentReader.book}/{currentReader.chapter}/{currentVerse}/")
			let html = payload and payload.commentaryHtml ? payload.commentaryHtml : ''
			let plain = htmlToPlainText(html) or (payload and payload.commentaryText ? payload.commentaryText : '')
			commentaryHtml = localizeCommentaryRefs(html, currentReader.translation)
			commentaryBlocks = splitCommentaryHtmlIntoBlocks(html, plain)
		catch err
			error = err and err.message ? err.message : (t.commentary_unavailable or 'Unable to load commentary')
		finally
			loading = no
			imba.commit!
			imba.commit!.then do applyCommentaryTypography!

	@autorun def syncAndReload
		const action = activities.activeVerseAction
		const selectedPKs = activities.selectedVersesPKs and activities.selectedVersesPKs.length
		const versesLoaded = currentReader.verses and currentReader.verses.length
		if action == 'commentary' and selectedPKs > 0 and versesLoaded
			clampCurrentVerse!
			loadCommentary!

	<self>
		<div.commentary-overlay @click=close>
		<section.commentary-modal @click.stop>
			<header>
				<div.header-top>
					<div.header-actions-slot>
						if commentaryHtml and commentaryHtml.length
							<button.obsidian-btn.header-action-btn .obsidian-active=obsidianMode @click.stop=toggleObsidianMode title="Obsidian">
								<svg src=Obsidian aria-hidden=yes>
							<button.compare-btn.header-action-btn .compare-active=compareMode @click.stop=toggleCompareMode title=(t.compare or "Compare")>
								<svg src=Split aria-hidden=yes>
						else
							<span.header-spacer aria-hidden=yes>
					<h3> commentaryTitle
					<button.close-btn.header-action-btn @click=close title="Close">
						<svg src=X>
				<div.header-nav>
					<button.nav-btn.nav-prev @click=stepVerse(-1) disabled=!canGoPrev title="Previous verse">
						<svg src=ChevronLeft>
					<p.verse-ref> commentaryReference
					<button.nav-btn.nav-next @click=stepVerse(1) disabled=!canGoNext title="Next verse">
						<svg src=ChevronRight>
			<div.content [ff:{theme.fontFamily} fs:{theme.fontSize}px lh:{theme.lineHeight} fw:{theme.fontWeight}] style=contentStyle>
				if loading
					<p.status> (t.commentary_loading or "Loading commentary...")
				elif error
					<p.error> error
				elif commentaryHtml and commentaryHtml.length
					<div.commentary-text [ff:{theme.fontFamily} fs:{theme.fontSize}px lh:{commentaryLineHeight} fw:{theme.fontWeight}] style=contentStyle innerHTML=commentaryHtml>
					if obsidianMode
						<div.commentary-obsidian-root>
							if obsidianBoxVisible
								<div.commentary-obsidian-box [top:{obsidianBoxTop}px height:{obsidianBoxHeight}px]>
									<span.commentary-obsidian-handle-top
										@mousedown.prevent.stop=(do |e| startObsidianDrag('top', e))
										@touchstart.prevent.stop=(do |e| startObsidianDrag('top', e))
										@pointerdown.prevent.stop=(do |e| startObsidianDrag('top', e))>
									<span.commentary-obsidian-handle-bottom
										@mousedown.prevent.stop=(do |e| startObsidianDrag('bottom', e))
										@touchstart.prevent.stop=(do |e| startObsidianDrag('bottom', e))
										@pointerdown.prevent.stop=(do |e| startObsidianDrag('bottom', e))>
									<button.commentary-obsidian-insert-btn @click.stop.prevent=sendCommentaryToObsidian title="Obsidian">
										<svg src=ChevronLeft aria-hidden=yes>
									<button.commentary-obsidian-close-btn @click.stop.prevent=toggleObsidianMode title="Close">
										<svg src=X aria-hidden=yes>
				else
					<p.status> (t.commentary_none_for_verse or "No commentary available for this verse.")

	css
		pos: fixed
		inset: 0
		zi: 1300
		d: flex
		ai: center
		jc: center
		padding: 1rem

		.commentary-overlay
			pos: absolute
			inset: 0
			bgc: rgba(15, 23, 42, 0.35)

		.commentary-modal
			pos: relative
			zi: 1
			width: min(56rem, 100%)
			max-height: min(75vh, 42rem)
			bgc: $bgc
			color: $c
			rd: 0.75rem
			bxs: 0 10px 30px rgba(0, 0, 0, 0.25)
			d: flex
			fld: column
			overflow: hidden

		header
			d: flex
			fld: column
			g: 0.65rem
			padding: 0.85rem 1.25rem 0.85rem
			bdb: 1px solid $acc-bgc

		.header-top
			d: grid
			grid-template-columns: 1fr auto 1fr
			ai: center
			g: 0.5rem
			min-height: 2.125rem

		.header-actions-slot
			d: flex
			ai: center
			g: 0.35rem
			justify-self: start
			min-height: 2.125rem
			flex-shrink: 0

		.header-spacer
			d: block
			width: calc(2.125rem * 2 + 0.35rem)
			height: 2.125rem
			flex-shrink: 0

		.header-nav
			d: flex
			ai: center
			jc: center
			pos: relative
			min-height: 2rem

		h3
			m: 0
			fs: 1rem
			fw: 700
			lh: 1.3
			ta: center
			justify-self: center
			min-width: 0

		.verse-ref
			m: 0
			c: $acc
			fs: 1.15rem
			fw: 700
			lh: 1.2
			ta: center
			min-width: 0
			padding-inline: 2.35rem

		.header-action-btn
			d: inline-flex
			ai: center
			jc: center
			size: 2.125rem
			p: 0
			rd: 0.4rem
			cursor: pointer
			flex-shrink: 0
			box-sizing: border-box

		.obsidian-btn
			bgc: transparent
			c: $acc @hover:$acc-hover
			border: none
			opacity: 0.75 @hover:1
			svg
				size: 1.35rem
				c: inherit
				opacity: 0.75 @hover:1

		.obsidian-btn.obsidian-active
			c: #a855f7
			opacity: 1
			svg
				c: #a855f7
				opacity: 1

		.compare-btn
			bgc: transparent
			c: $acc @hover:$acc-hover
			border: none
			opacity: 0.75 @hover:1
			svg
				size: 1.35rem
				c: inherit
				opacity: 0.75 @hover:1

		.compare-btn.compare-active
			c: GoldenRod
			opacity: 1
			svg
				c: GoldenRod
				opacity: 1

		.close-btn
			bgc: transparent
			c: $c @hover:$acc-hover
			p: 0
			justify-self: end
			svg
				size: 1.35rem

		.nav-btn
			pos: absolute
			top: 50%
			transform: translateY(-50%)
			size: 1.75rem
			bgc: $acc-bgc
			c: $c
			p: 0
			rd: 0.35rem
			cursor: pointer
			d: hcc
			flex-shrink: 0
			&:disabled
				opacity: 0.35
				cursor: not-allowed
			svg
				size: 0.95rem

		.nav-prev
			left: 0

		.nav-next
			right: 0

		.content
			overflow: auto
			padding: 1.25rem 30px
			margin-left: 20px
			margin-right: 20px
			-webkit-overflow-scrolling: touch

		.content.commentary-obsidian-active
			pos: relative

		.commentary-obsidian-root
			pos: absolute
			top: 0
			left: 0
			right: 0
			bottom: 0
			pointer-events: none
			zi: 2

		.commentary-obsidian-box
			pos: absolute
			left: 0
			right: 0
			border-radius: 8px
			background: color-mix(in srgb, #a855f7 15%, transparent)
			border: 2px solid #a855f7
			zi: 10
			pointer-events: none
			box-sizing: border-box
			padding-left: 20px
			padding-right: 20px
			transition: top 150ms ease, height 150ms ease

		html[data-commentary-obsidian-dragging="true"] .commentary-obsidian-box
			transition: none

		.commentary-obsidian-insert-btn
			pos: absolute
			left: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 6px 0 0 6px
			d: flex
			ai: center
			jc: center
			cursor: pointer
			pointer-events: auto
			z-index: 12
			padding: 0
			margin: 0
			color: white
			svg
				width: 14px
				height: 14px
				display: block

		.commentary-obsidian-close-btn
			pos: absolute
			right: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 0 6px 6px 0
			d: flex
			ai: center
			jc: center
			cursor: pointer
			pointer-events: auto
			z-index: 12
			padding: 0
			margin: 0
			color: white
			svg
				width: 14px
				height: 14px
				display: block

		.commentary-obsidian-handle-top
			pos: absolute
			left: 50%
			transform: translateX(-50%)
			top: -4px
			width: 64px
			height: 6px
			border-radius: 999px
			background: #a855f7
			cursor: ns-resize
			pointer-events: auto
			z-index: 6
			touch-action: none

		.commentary-obsidian-handle-bottom
			pos: absolute
			left: 50%
			transform: translateX(-50%)
			bottom: -4px
			width: 64px
			height: 6px
			border-radius: 999px
			background: #a855f7
			cursor: ns-resize
			pointer-events: auto
			z-index: 6
			touch-action: none

		.commentary-text
			word-break: break-word
			text-align: left

			.cba-heading
				m-bottom: 0.35rem
				c: $acc
				fw: 600
				fs: 0.95em

		.status
			m: 0
			c: $acc
			ta: center
			padding-block: 2rem

		.error
			c: #ef4444
			m: 0
			ta: center
			padding-block: 2rem

global css
	.commentary-modal .commentary-text p
		margin: 0
		padding-top: var(--cmt-pt, 0.5em)
		padding-bottom: var(--cmt-pb, 1.2em)

	.commentary-modal .commentary-text p:first-child
		padding-top: 0

	.commentary-modal .commentary-text p:last-child
		padding-bottom: 0

	.commentary-modal .commentary-text [data-block-idx]
		cursor: pointer
