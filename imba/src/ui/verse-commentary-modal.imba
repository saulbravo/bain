import activities from '../lib/Activities'
import API from '../lib/Api'
import commentaries from '../lib/Commentaries'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import theme from '../lib/Theme'
import user from '../lib/User'
import { getBookName, getValue, setValue } from '../utils'
import { localizeCommentaryRefs, htmlToPlainText, splitCommentaryHtmlIntoBlocks } from '../utils/cbaBooks'
import { wrapHtmlTextHighlights } from '../lib/highlightStyles'
import X from 'lucide-static/icons/x.svg'
import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import ChevronRight from 'lucide-static/icons/chevron-right.svg'
import Pencil from 'lucide-static/icons/pencil.svg'
import Check from 'lucide-static/icons/check.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import Obsidian from '../icons/obsidian.svg'
import Split from 'lucide-static/icons/split.svg'

tag verse-commentary-modal
	loading = no
	error = ''
	commentaryHtml = ''
	commentaryBlocks = []
	obsidianMode = no
	exportStartIdx = 0
	exportEndIdx = 0
	obsidianBoxTop = 0
	obsidianBoxHeight = 0
	obsidianBoxVisible = no
	currentVerse = 0
	lastLoadKey = ''
	showEditor = no
	compareTopPad = 0
	#onCompareResize = null
	#compareObserver = null
	#onObsidianScroll = null
	#obsidianBlockClicks = []
	obsidianDragging = no
	obsidianDragHandle = ''
	lastDragBlockIdx = -1
	obsidianDragRAF = null
	#obsidianBlockClickLock = no
	commentaryHighlights = []
	chapterCommentaryHighlights = []
	freehandStrokeCanvas = null
	freehandStrokeCtx = null
	freehandStrokePoints = []
	freehandStrokeDrawing = no
	currentDragHighlight = null
	capturedPointerId = null
	#boundFreehandMove = null
	#boundFreehandUp = null
	freehandSelectionAnchor = null
	freehandSelectionFocus = null
	#onCommentaryClear = null
	#onCommentaryUndo = null

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
		return commentaries.currentName

	get displayedCommentaryHtml
		if !commentaryHtml
			return ''
		if !commentaryHighlights or commentaryHighlights.length == 0
			return commentaryHtml
		try
			return wrapHtmlTextHighlights(commentaryHtml, commentaryHighlights)
		catch err
			return commentaryHtml

	get commentaryFreehandArmed
		return activities.freehandHighlightMode and !obsidianMode

	get commentaryEraseArmed
		return commentaryFreehandArmed and activities.freehandEraserMode

	get commentaryHighlightColor
		return activities.freehandHighlightColor or '#F9E2A0'

	def commentaryHighlightStorageKey
		return "commentary-freehand:{commentaries.current}:{currentReader.book}:{currentReader.chapter}:{currentVerse}"

	def commentaryApiTranslation
		let id = String(commentaries.current or 'cba').replace(/[^A-Za-z0-9_-]/g, '-')
		return "cmt-{id}"

	def highlightsForCurrentVerse list
		let verse = Number(currentVerse)
		let out = []
		for item in (list or [])
			if Number(item.startVerse) != verse
				continue
			out.push({
				start: Number(item.startOffset or 0)
				end: Number(item.endOffset or 0)
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or Date.now()
			})
		return out

	def loadCommentaryHighlights
		let stored = getValue(commentaryHighlightStorageKey!)
		commentaryHighlights = Array.isArray(stored) ? stored.slice() : []
		activities.commentaryFreehandCount = commentaryHighlights.length
		chapterCommentaryHighlights = []
		if !user.username or !window.navigator.onLine
			return
		try
			let remote = await API.getJson("/get-freehand-highlights/{commentaryApiTranslation!}/{currentReader.book}/{currentReader.chapter}/")
			if Array.isArray(remote)
				chapterCommentaryHighlights = remote.slice()
				let fromRemote = highlightsForCurrentVerse(remote)
				if fromRemote.length or commentaryHighlights.length == 0
					commentaryHighlights = fromRemote
					activities.commentaryFreehandCount = commentaryHighlights.length
		catch err
			pass

	def saveCommentaryHighlights
		const now = Date.now()
		commentaryHighlights = (commentaryHighlights or []).map(do |item|
			return {
				start: Number(item.start or 0)
				end: Number(item.end or 0)
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or now
			}
		)
		setValue(commentaryHighlightStorageKey!, commentaryHighlights)
		activities.commentaryFreehandCount = commentaryHighlights.length
		let verse = Number(currentVerse)
		let others = []
		for item in (chapterCommentaryHighlights or [])
			if Number(item.startVerse) == verse
				continue
			others.push(item)
		for item in commentaryHighlights
			others.push({
				startVerse: verse
				startOffset: item.start
				endVerse: verse
				endOffset: item.end
				color: item.color
				decoration: item.decoration or 'fill'
				underlineStyle: item.underlineStyle or 'solid'
				date: item.date or now
			})
		chapterCommentaryHighlights = others
		if !user.username or !window.navigator.onLine
			imba.commit!
			return
		try
			await API.post("/save-freehand-highlights/", {
				translation: commentaryApiTranslation!
				book: currentReader.book
				chapter: currentReader.chapter
				highlights: chapterCommentaryHighlights
			})
		catch err
			pass
		imba.commit!

	def toggleCommentaryFreehand
		if obsidianMode
			obsidianMode = no
			teardownObsidianUI!
		activities.toggleFreehandHighlightMode!

	def commentaryTextRoot
		return self.querySelector('.commentary-text')

	def commentaryPlainOffsetFromNode root, node, offset
		let total = 0
		let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
		while walker.nextNode!
			let n = walker.currentNode
			if n == node
				return total + Number(offset or 0)
			total += (n.textContent or '').length
		return total

	def commentaryPlainOffsetFromPoint x, y
		let root = commentaryTextRoot!
		return unless root
		let range = null
		if document.caretRangeFromPoint
			range = document.caretRangeFromPoint(x, y)
		elif document.caretPositionFromPoint
			let pos = document.caretPositionFromPoint(x, y)
			if pos and pos.offsetNode
				range = document.createRange()
				range.setStart(pos.offsetNode, pos.offset)
				range.collapse(yes)
		return unless range
		let node = range.startContainer
		if node and node.nodeType == 3
			node = node.parentElement
		if node and root.contains(node)
			return commentaryPlainOffsetFromNode(root, range.startContainer, range.startOffset)
		return null

	def commentaryClientPoint e
		if e and e.touches and e.touches[0]
			return { x: e.touches[0].clientX, y: e.touches[0].clientY }
		if e and e.changedTouches and e.changedTouches[0]
			return { x: e.changedTouches[0].clientX, y: e.changedTouches[0].clientY }
		return { x: e.clientX, y: e.clientY }

	def ensureCommentaryFreehandCanvas
		let canvas = self.querySelector('.commentary-freehand-canvas')
		return unless canvas
		let content = getContentEl!
		return unless content
		let width = content.clientWidth
		let height = content.clientHeight
		if canvas.width != width or canvas.height != height
			canvas.width = width
			canvas.height = height
		freehandStrokeCanvas = canvas
		freehandStrokeCtx = canvas.getContext('2d')
		return freehandStrokeCtx

	def drawCommentaryFreehandStroke
		# Underline mode draws straight onto the text, so no canvas preview.
		return if activities.patternHighlightMode
		let ctx = ensureCommentaryFreehandCanvas!
		return unless ctx and freehandStrokeCanvas
		ctx.clearRect(0, 0, freehandStrokeCanvas.width, freehandStrokeCanvas.height)
		return unless freehandStrokePoints.length
		let color = commentaryHighlightColor
		ctx.strokeStyle = color
		ctx.lineWidth = 14
		ctx.lineCap = 'round'
		ctx.lineJoin = 'round'
		ctx.globalAlpha = 0.35
		ctx.setLineDash([])
		ctx.beginPath!
		ctx.moveTo(freehandStrokePoints[0].x, freehandStrokePoints[0].y)
		for point, index in freehandStrokePoints
			if index == 0
				continue
			ctx.lineTo(point.x, point.y)
		ctx.stroke!

	def clearCommentaryFreehandStroke
		if freehandStrokeCtx and freehandStrokeCanvas
			freehandStrokeCtx.clearRect(0, 0, freehandStrokeCanvas.width, freehandStrokeCanvas.height)
		freehandStrokePoints = []
		freehandStrokeDrawing = no

	def applyCommentaryHighlightRange start, end, isFinal = no
		if !(end > start)
			let tmp = start
			start = end
			end = tmp
		if !(end > start)
			return
		if commentaryEraseArmed
			let out = []
			for h in (commentaryHighlights or [])
				let hs = Number(h.start or 0)
				let he = Number(h.end or 0)
				if he <= start or hs >= end
					out.push(h)
					continue
				if hs < start
					out.push({
						start: hs
						end: start
						color: h.color
						decoration: h.decoration or 'fill'
						underlineStyle: h.underlineStyle or 'solid'
						date: h.date or Date.now()
					})
				if he > end
					out.push({
						start: end
						end: he
						color: h.color
						decoration: h.decoration or 'fill'
						underlineStyle: h.underlineStyle or 'solid'
						date: h.date or Date.now()
					})
			commentaryHighlights = out
			if isFinal
				saveCommentaryHighlights!
			else
				activities.commentaryFreehandCount = commentaryHighlights.length
				imba.commit!
			return
		let decoration = activities.patternHighlightMode ? 'underline' : 'fill'
		let highlight = {
			start: start
			end: end
			color: commentaryHighlightColor
			decoration: decoration
			underlineStyle: activities.underlineStyle or 'solid'
			date: Date.now()
		}
		if currentDragHighlight
			commentaryHighlights[commentaryHighlights.length - 1] = highlight
		else
			commentaryHighlights.push(highlight)
		currentDragHighlight = isFinal ? null : highlight
		if isFinal
			saveCommentaryHighlights!
		else
			activities.commentaryFreehandCount = commentaryHighlights.length
			imba.commit!

	def commitCommentaryFreehandFromStroke isFinal = yes
		return unless commentaryFreehandArmed
		let start = null
		let end = null
		for point in freehandStrokePoints
			let off = commentaryPlainOffsetFromPoint(point.clientX, point.clientY)
			if off == null
				continue
			if start == null or off < start
				start = off
			if end == null or off > end
				end = off
		let selection = window.getSelection()
		if selection and !selection.isCollapsed
			let root = commentaryTextRoot!
			if root
				try
					let range = selection.getRangeAt(0)
					let a = commentaryPlainOffsetFromNode(root, range.startContainer, range.startOffset)
					let b = commentaryPlainOffsetFromNode(root, range.endContainer, range.endOffset)
					if a != null and b != null
						start = Math.min(a, b)
						end = Math.max(a, b)
				catch err
					pass
		if start == null or end == null
			return
		applyCommentaryHighlightRange(start, end, isFinal)
		if isFinal and selection
			selection.removeAllRanges()

	def stopCommentaryFreehandListeners
		if #boundFreehandMove
			window.removeEventListener('pointermove', #boundFreehandMove)
			window.removeEventListener('pointerup', #boundFreehandUp)
			window.removeEventListener('pointercancel', #boundFreehandUp)
			#boundFreehandMove = null
			#boundFreehandUp = null
		if typeof capturedPointerId == 'number'
			try
				if self.releasePointerCapture
					self.releasePointerCapture(capturedPointerId)
			catch err
				pass
			capturedPointerId = null
		clearCommentaryFreehandStroke!
		currentDragHighlight = null

	def handleCommentaryFreehandMove e
		return unless freehandStrokeDrawing
		if e and e.preventDefault
			e.preventDefault()
		let point = commentaryClientPoint(e)
		let content = getContentEl!
		let rect = content ? content.getBoundingClientRect() : { left: 0, top: 0 }
		freehandStrokePoints.push({
			x: point.x - rect.left
			y: point.y - rect.top
			clientX: point.x
			clientY: point.y
		})
		unless activities.patternHighlightMode
			drawCommentaryFreehandStroke!
		if commentaryEraseArmed
			commitCommentaryFreehandFromStroke(no)
		elif activities.patternHighlightMode
			let off = commentaryPlainOffsetFromPoint(point.x, point.y)
			if off != null
				freehandSelectionFocus = off
				let root = commentaryTextRoot!
				let selection = window.getSelection()
				if root and selection and freehandSelectionAnchor != null
					try
						let a = locateForSelection(root, freehandSelectionAnchor)
						let b = locateForSelection(root, off)
						if a and b
							let range = document.createRange()
							range.setStart(a.node, a.offset)
							range.setEnd(b.node, b.offset)
							if range.collapsed
								range.setStart(b.node, b.offset)
								range.setEnd(a.node, a.offset)
							selection.removeAllRanges()
							selection.addRange(range)
					catch err
						pass
			commitCommentaryFreehandFromStroke(no)

	def locateForSelection root, offset
		let remaining = Number(offset or 0)
		let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT)
		while walker.nextNode!
			let node = walker.currentNode
			let len = (node.textContent or '').length
			if remaining <= len
				return { node: node, offset: remaining }
			remaining -= len
		return null

	def handleCommentaryFreehandUp e
		if e and e.preventDefault
			e.preventDefault()
		commitCommentaryFreehandFromStroke(yes)
		stopCommentaryFreehandListeners!

	def handleCommentaryFreehandDown e
		return unless commentaryFreehandArmed
		if e and e.target and e.target.closest
			if e.target.closest('button, a, .commentary-tab, header')
				return
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		stopCommentaryFreehandListeners!
		freehandStrokeDrawing = yes
		currentDragHighlight = null
		let point = commentaryClientPoint(e)
		let content = getContentEl!
		let rect = content ? content.getBoundingClientRect() : { left: 0, top: 0 }
		freehandStrokePoints = [{
			x: point.x - rect.left
			y: point.y - rect.top
			clientX: point.x
			clientY: point.y
		}]
		freehandSelectionAnchor = commentaryPlainOffsetFromPoint(point.x, point.y)
		freehandSelectionFocus = freehandSelectionAnchor
		if typeof e.pointerId == 'number' and content and content.setPointerCapture
			try
				content.setPointerCapture(e.pointerId)
				capturedPointerId = e.pointerId
			catch err
				pass
		#boundFreehandMove = handleCommentaryFreehandMove.bind(self)
		#boundFreehandUp = handleCommentaryFreehandUp.bind(self)
		window.addEventListener('pointermove', #boundFreehandMove, { passive: no })
		window.addEventListener('pointerup', #boundFreehandUp)
		window.addEventListener('pointercancel', #boundFreehandUp)
		unless activities.patternHighlightMode
			drawCommentaryFreehandStroke!

	def clearCommentaryFreehandHighlights
		commentaryHighlights = []
		saveCommentaryHighlights!

	def undoCommentaryFreehandHighlight
		if !commentaryHighlights or commentaryHighlights.length == 0
			return
		commentaryHighlights = commentaryHighlights.slice(0, -1)
		saveCommentaryHighlights!

	def selectCommentary id\string
		return if id == commentaries.current
		commentaries.select(id)
		lastLoadKey = ''
		loadCommentary!
		imba.commit!.then do scrollActiveTabIntoView!

	def toggleSource id\string
		const previous = commentaries.current
		commentaries.toggle(id)
		# Hiding the tab you were reading falls back to another module.
		if commentaries.current != previous
			lastLoadKey = ''
			loadCommentary!
		imba.commit!.then do scrollActiveTabIntoView!

	def scrollActiveTabIntoView
		const strip = self.querySelector('.commentary-tabs')
		const tab = strip and strip.querySelector('.commentary-tab.active')
		return unless tab
		strip.scrollLeft = Math.max(0, tab.offsetLeft - (strip.clientWidth - tab.offsetWidth) / 2)

	get contentStyle
		const base = "--cmt-pt:{commentaryLineHeight - 1}em;--cmt-pb:{0.8 * commentaryLineHeight}em"
		if embedded
			return base + ";margin-left:0;margin-right:0;padding:1.25rem;box-sizing:border-box;overflow-wrap:anywhere"
		return base

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

	def mount
		watchCompareHeaderOffset!
		#onCommentaryClear = do clearCommentaryFreehandHighlights!
		#onCommentaryUndo = do undoCommentaryFreehandHighlight!
		window.addEventListener('commentary-freehand-clear', #onCommentaryClear)
		window.addEventListener('commentary-freehand-undo', #onCommentaryUndo)
		await commentaries.load!
		imba.commit!.then do
			scrollActiveTabIntoView!
			syncCompareHeaderOffset!

	def unmount
		teardownObsidianUI!
		stopCommentaryFreehandListeners!
		unwatchCompareHeaderOffset!
		if #onCommentaryClear
			window.removeEventListener('commentary-freehand-clear', #onCommentaryClear)
			#onCommentaryClear = null
		if #onCommentaryUndo
			window.removeEventListener('commentary-freehand-undo', #onCommentaryUndo)
			#onCommentaryUndo = null
		activities.commentaryFreehandCount = 0

	# In compare mode the header grows until its bottom border lines up with the
	# line under the reader's tabs, so both panes share one divider.
	def offsetWithin el, ancestor
		let node = el
		let y = 0
		while node and node != ancestor
			y += node.offsetTop
			node = node.offsetParent
		return node ? y : null

	def syncCompareHeaderOffset
		unless embedded
			compareTopPad = 0
			return
		const main = document.getElementById('main')
		const header = self.querySelector('header')
		const anchor = document.querySelector('#main-reader .tabs-sticky') or document.querySelector('#main-reader header')
		return unless main and header and anchor
		const anchorTop = offsetWithin(anchor, main)
		const headerTop = offsetWithin(header, main)
		return if anchorTop == null or headerTop == null
		# Stacked panes on narrow screens have nothing to line up with.
		return if Math.abs(header.getBoundingClientRect().left - anchor.getBoundingClientRect().left) < 1
		const delta = (anchorTop + anchor.offsetHeight) - (headerTop + header.offsetHeight)
		return if Math.abs(delta) > 200
		const currentPad = parseFloat(window.getComputedStyle(header).paddingTop) or 0
		const next = Math.min(96, Math.max(0, currentPad + delta))
		if Math.abs(next - compareTopPad) > 0.5
			compareTopPad = next
			imba.commit!

	def watchCompareHeaderOffset
		return unless embedded
		#onCompareResize = do syncCompareHeaderOffset!
		window.addEventListener('resize', #onCompareResize)
		const anchor = document.querySelector('#main-reader header')
		if anchor and window.ResizeObserver
			#compareObserver = new ResizeObserver(#onCompareResize)
			#compareObserver.observe(anchor)

	def unwatchCompareHeaderOffset
		if #onCompareResize
			window.removeEventListener('resize', #onCompareResize)
			#onCompareResize = null
		if #compareObserver
			#compareObserver.disconnect!
			#compareObserver = null

	def closeFromBackdrop e
		if e and e.target and e.target.closest
			if e.target.closest('freehand-highlight-menu')
				return
		close!

	def close
		stopObsidianDragListeners!
		teardownObsidianUI!
		stopCommentaryFreehandListeners!
		obsidianMode = no
		resetExportRange!
		lastLoadKey = ''
		if activities.freehandHighlightMode
			activities.toggleFreehandHighlightMode!
		if activities.commentaryCompareMode
			activities.commentaryCompareMode = no
			activities.commentaryCompareVerse = 0
			if activities.selectedVersesPKs.length > 0
				activities.activeVerseAction = 'options'
			else
				activities.activeVerseAction = ''
		else
			activities.activeVerseAction = 'options'
		imba.commit!

	def toggleCompareMode
		if activities.commentaryCompareMode
			activities.commentaryCompareMode = no
			activities.commentaryCompareVerse = 0
			if activities.selectedVersesPKs.length > 0
				activities.activeVerseAction = 'options'
			else
				activities.activeVerseAction = ''
		else
			clampCurrentVerse!
			activities.commentaryCompareVerse = currentVerse
			activities.commentaryCompareMode = yes
			teardownObsidianUI!
			obsidianMode = no
			activities.activeVerseAction = 'suppressed'
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

	def focusCompareVerse verseNum
		let target = Number(verseNum)
		let match = null
		for v in (currentReader.verses or [])
			if Number(v.verse) == target
				match = v
				break
		unless match
			return
		activities.selectedVersesPKs = [match.pk]
		activities.selectedVerses = [match.verse]
		activities.selectedCategories = []
		activities.commentaryCompareVerse = target
		activities.activeVerseAction = 'suppressed'
		activities.selectedParallel = currentReader.me
		const id = currentReader.me == 'main' ? String(target) : "p{target}"
		const el = document.getElementById(id)
		if el and el.scrollIntoView
			el.scrollIntoView({
				behavior: theme.scrollBehavior or 'auto'
				block: 'nearest'
			})

	def stepVerse delta\number
		let nums = getVerseNumbers!
		return if nums.length == 0
		let idx = nums.indexOf(Number(currentVerse))
		if idx < 0
			idx = 0
		let next = Math.max(0, Math.min(nums.length - 1, idx + delta))
		if next == idx and nums[next] == Number(currentVerse)
			return
		currentVerse = nums[next]
		if activities.commentaryCompareMode
			focusCompareVerse(currentVerse)
		teardownObsidianUI!
		obsidianMode = no
		resetExportRange!
		imba.commit!
		loadCommentary!

	get canGoPrev
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(Number(currentVerse))
		return idx > 0

	get canGoNext
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(Number(currentVerse))
		return idx >= 0 and idx < nums.length - 1

	def loadCommentary
		clampCurrentVerse!
		return if currentVerse <= 0
		let key = "{commentaries.current}:{currentReader.translation}:{currentReader.book}:{currentReader.chapter}:{currentVerse}"
		return if key == lastLoadKey
		lastLoadKey = key
		loading = yes
		error = ''
		commentaryHtml = ''
		commentaryBlocks = []
		teardownObsidianUI!
		obsidianMode = no
		resetExportRange!
		imba.commit!
		try
			let payload = await API.getJson("/get-commentary/{commentaries.current}/{currentReader.book}/{currentReader.chapter}/{currentVerse}/")
			let html = payload and payload.commentaryHtml ? payload.commentaryHtml : ''
			let plain = htmlToPlainText(html) or (payload and payload.commentaryText ? payload.commentaryText : '')
			commentaryHtml = localizeCommentaryRefs(html, currentReader.translation)
			commentaryBlocks = splitCommentaryHtmlIntoBlocks(html, plain)
		catch err
			error = err and err.message ? err.message : (t.commentary_unavailable or 'Unable to load commentary')
		finally
			loading = no
			loadCommentaryHighlights!
			imba.commit!
			imba.commit!.then do applyCommentaryTypography!

	@autorun def syncAndReload
		const action = activities.activeVerseAction
		const selectedPKs = activities.selectedVersesPKs and activities.selectedVersesPKs.length
		const versesLoaded = currentReader.verses and currentReader.verses.length

		if activities.commentaryCompareMode and versesLoaded
			# A selection in the reader always wins, so switching tabs or picking
			# another verse retargets the commentary instead of closing it.
			const selected = getSelectedVerseNumbers!
			if selected.length
				currentVerse = selected[selected.length - 1]
			elif activities.commentaryCompareVerse > 0
				currentVerse = activities.commentaryCompareVerse
			clampCurrentVerse!
			if activities.commentaryCompareVerse != currentVerse
				activities.commentaryCompareVerse = currentVerse
			loadCommentary!
			return

		if action == 'commentary' and selectedPKs > 0 and versesLoaded
			clampCurrentVerse!
			loadCommentary!

	get embedded
		return activities.commentaryCompareMode

	get rootStyle
		if embedded
			const grow = 1 - activities.splitRatio
			return "position:relative;top:auto;left:auto;right:auto;bottom:auto;z-index:auto;display:flex;flex-direction:column;align-items:stretch;justify-content:flex-start;flex:{grow} 1 0;width:auto;height:auto;min-width:0;min-height:0;overflow:hidden;padding:0;box-sizing:border-box"
		# Top-aligned so the header and tabs stay put while only the bottom edge
		# follows the length of the commentary.
		return "position:fixed;top:0;left:0;right:0;bottom:0;z-index:1300;display:flex;flex-direction:row;align-items:flex-start;justify-content:center;flex:0 0 auto;height:auto;min-width:0;min-height:0;overflow:visible;padding:12vh 1rem 1rem"

	get paneStyle
		if embedded
			return "flex:1 1 auto;width:100%;height:100%;max-height:100%;min-width:0;min-height:0;border-radius:0;box-shadow:none;box-sizing:border-box"
		return "flex:0 0 auto;width:min(56rem, 100%);height:auto;max-height:min(75vh, 42rem);min-height:min(28rem, 58vh);border-radius:0.75rem;box-shadow:0 10px 30px rgba(0, 0, 0, 0.25)"

	<self .commentary-root .commentary-embedded=embedded style=rootStyle>
		unless embedded
			<div.commentary-overlay @click=closeFromBackdrop>
		<section .commentary-modal=!embedded .commentary-pane=embedded @click.stop style=paneStyle>
			<header [padding-top:{compareTopPad}px]=(embedded and compareTopPad > 0)>
				<div.header-top>
					<div.header-actions-slot>
						if commentaryHtml and commentaryHtml.length
							<button.obsidian-btn.header-action-btn .obsidian-active=obsidianMode @click.stop=toggleObsidianMode title="Obsidian">
								<svg src=Obsidian aria-hidden=yes>
						if commentaryHtml and commentaryHtml.length
							<button.freehand-btn.header-action-btn .freehand-active=activities.freehandHighlightMode @click.stop=toggleCommentaryFreehand title="Freehand Highlight">
								<svg src=Highlighter aria-hidden=yes>
						if activities.commentaryCompareMode or loading or (commentaryHtml and commentaryHtml.length)
							<button.compare-btn.header-action-btn .compare-active=activities.commentaryCompareMode @click.stop=toggleCompareMode title=(t.compare or "Compare")>
								<svg src=Split aria-hidden=yes>
						if !(commentaryHtml and commentaryHtml.length) and !activities.commentaryCompareMode and !loading
							<span.header-spacer aria-hidden=yes>
					<h3.commentary-name> commentaryTitle
					<div.header-right>
						<menu-popup.tab-editor bind=showEditor scrollinview=no>
							<button.edit-tabs-btn.header-action-btn .editing=showEditor @click.stop=(do showEditor = !showEditor) title=(t.commentaries or "Choose commentaries")>
								<svg src=Pencil aria-hidden=yes>
							if showEditor
								<div.tab-editor-menu>
									for source in commentaries.sources
										<button.tab-editor-item .picked=commentaries.isEnabled(source.id) .locked=commentaries.isPinned(source.id)
											@click.stop=(do toggleSource(source.id)) disabled=commentaries.isPinned(source.id)>
											<span.tab-editor-box>
												if commentaries.isEnabled(source.id)
													<svg src=Check aria-hidden=yes>
											<span.tab-editor-name> source.name
											<span.tab-editor-short> commentaries.shortNameFor(source)
						<button.close-btn.header-action-btn @click=close title="Close">
							<svg src=X>
				<div.header-nav>
					<button.nav-btn.nav-prev @click=stepVerse(-1) disabled=!canGoPrev title="Previous verse">
						<svg src=ChevronLeft>
					<p.verse-ref> commentaryReference
					<button.nav-btn.nav-next @click=stepVerse(1) disabled=!canGoNext title="Next verse">
						<svg src=ChevronRight>
				<div.commentary-tabs>
					for source in commentaries.visibleSources
						<button.commentary-tab .active=(source.id == commentaries.current)
							@click.stop=(do selectCommentary(source.id)) title=source.name>
							commentaries.shortNameFor(source)
			<div.content .commentary-obsidian-active=obsidianMode .commentary-freehand-active=commentaryFreehandArmed [ff:{theme.fontFamily} fs:{theme.fontSize}px lh:{theme.lineHeight} fw:{theme.fontWeight}] style=contentStyle
				@pointerdown=handleCommentaryFreehandDown>
				if loading
					<p.status> (t.commentary_loading or "Loading commentary...")
				elif error
					<p.error> error
				elif commentaryHtml and commentaryHtml.length
					if commentaryFreehandArmed
						<canvas.commentary-freehand-canvas>
					<div.commentary-text [ff:{theme.fontFamily} fs:{theme.fontSize}px lh:{commentaryLineHeight} fw:{theme.fontWeight}] style=contentStyle innerHTML=displayedCommentaryHtml>
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
		ai: flex-start
		jc: center
		padding: 12vh 1rem 1rem

		&.commentary-root--embedded
			pos: static
			inset: auto
			zi: auto
			d: flex
			fld: column
			flex: 1 1 0
			min-width: 0
			min-h: 0
			overflow: hidden
			padding: 0
			w: auto
			h: 100%
			max-h: 100%

		.commentary-overlay
			pos: absolute
			inset: 0
			bgc: rgba(15, 23, 42, 0.35)

		.commentary-modal
			pos: relative
			zi: 1
			width: min(56rem, 100%)
			max-height: min(75vh, 42rem)
			min-height: min(28rem, 58vh)
			bgc: $bgc
			color: $c
			rd: 0.75rem
			bxs: 0 10px 30px rgba(0, 0, 0, 0.25)
			d: flex
			fld: column
			overflow: hidden

		.commentary-pane
			pos: relative
			zi: 1
			width: 100%
			height: 100%
			min-width: 0
			min-h: 0
			flex: 1 1 auto
			bgc: $bgc
			color: $c
			d: flex
			fld: column
			overflow: hidden

			@lt-sm
				max-h: 50vh

		header
			pos: relative
			d: flex
			fld: column
			g: 0.7rem
			padding: 1.35rem 1.25rem 0.85rem
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

		.commentary-name
			m: 0
			fs: 1rem
			fw: 700
			lh: 1.3
			ta: center
			min-width: 0
			overflow: hidden
			text-overflow: ellipsis
			white-space: nowrap

		.header-right
			d: flex
			ai: center
			g: 0.35rem
			justify-self: end
			flex-shrink: 0

		# Static so the menu below anchors to the header, not to this button.
		.tab-editor
			d: flex
			ai: center

		.edit-tabs-btn
			bgc: transparent
			c: $c @hover:$acc-hover
			svg
				size: 1.15rem

		.edit-tabs-btn.editing
			bgc: $acc-bgc
			c: $acc

		.tab-editor-menu
			pos: absolute
			top: calc(100% + 0.45rem)
			left: 50%
			transform: translateX(-50%)
			zi: 30
			d: flex
			fld: column
			box-sizing: border-box
			min-width: min(20rem, 78vw)
			max-width: calc(100% - 2.5rem)
			# Kept under the modal's smallest height so it never gets clipped.
			max-height: min(16rem, 38vh)
			overflow-y: auto
			bgc: $bgc
			bd: 1px solid $acc-bgc
			rd: 0.5rem
			bxs: 0 10px 30px rgba(0, 0, 0, 0.25)
			padding: 0.25rem

		.tab-editor-item
			d: flex
			ai: center
			g: 0.5rem
			width: 100%
			ta: left
			padding: 0.45rem 0.55rem
			bd: none
			bgc: transparent
			color: inherit
			font: inherit
			fs: 0.85rem
			cursor: pointer
			rd: 0.35rem
			bgc@hover: $acc-bgc

		# CBA and EGW are always on, so they read as fixed rather than clickable.
		.tab-editor-item.locked
			cursor: default
			o: 0.55
			bgc@hover: transparent

		.tab-editor-box
			d: hcc
			size: 1.05rem
			flex: 0 0 auto
			bd: 1px solid $acc-bgc
			rd: 0.25rem
			svg
				size: 0.8rem

		.tab-editor-item.picked .tab-editor-box
			bgc: $acc
			bd: 1px solid $acc
			c: $bgc

		.tab-editor-item.locked .tab-editor-box
			bgc: $acc-bgc
			bd: 1px solid $acc-bgc
			c: $c

		.tab-editor-name
			flex: 1 1 auto
			min-width: 0
			overflow: hidden
			text-overflow: ellipsis
			white-space: nowrap

		.tab-editor-item.picked .tab-editor-name
			fw: 600

		.tab-editor-item.locked .tab-editor-name
			fw: 400

		.tab-editor-short
			flex: 0 0 auto
			fs: 0.7rem
			o: 0.6

		# Tabs hang off the bottom of the header so they sit on its border, the same
		# way the reader's chapter tabs sit on the line above the text.
		.commentary-tabs
			d: flex
			ai: flex-end
			g: 4px
			margin-inline: -1.25rem
			margin-bottom: -0.85rem
			padding-inline: 1.25rem
			overflow-x: auto
			overflow-y: visible
			scrollbar-width: none
			min-width: 0

			&::-webkit-scrollbar
				d: none

		.commentary-tab
			pos: relative
			zi: 1
			flex: 0 0 auto
			padding: 0.6rem 0.85rem
			bd: 1px solid transparent
			border-bottom: none
			bgc: $acc-bgc
			color: inherit
			font: inherit
			fs: 0.85rem
			lh: 1.25
			white-space: nowrap
			cursor: pointer
			rd: 0.5rem 0.5rem 0 0
			touch-action: manipulation
			transition: background-color 0.2s

			@hover
				bgc: $acc-bgc-hover

		.commentary-tab.active
			bgc: $bgc
			bd: 1px solid $acc-bgc
			border-bottom: none
			fw: 700
			color: $acc
			zi: 3

			@hover
				bgc: $bgc

			# Covers the header's border so the active tab joins the text below it.
			&::after
				content: ''
				pos: absolute
				left: -1px
				right: -1px
				bottom: -2px
				h: 3px
				bgc: $bgc
				zi: 4
				pointer-events: none

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

		.freehand-btn
			bgc: transparent
			c: $acc @hover:$acc-hover
			border: none
			opacity: 0.75 @hover:1
			svg
				size: 1.35rem
				c: inherit
				opacity: 0.75 @hover:1

		.freehand-btn.freehand-active
			c: var(--freehand-color, GoldenRod)
			opacity: 1
			svg
				c: var(--freehand-color, GoldenRod)
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
			flex: 1 1 auto
			min-h: 0
			pos: relative
			-webkit-overflow-scrolling: touch

		.content.commentary-freehand-active
			touch-action: none
			-webkit-touch-callout: none

		.commentary-freehand-canvas
			pos: absolute
			inset: 0
			w: 100%
			h: 100%
			pointer-events: none
			zi: 3

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

	.commentary-pane .commentary-text p
		margin: 0
		padding-top: var(--cmt-pt, 0.5em)
		padding-bottom: var(--cmt-pb, 1.2em)

	.commentary-modal .commentary-text p:first-child
		padding-top: 0

	.commentary-pane .commentary-text p:first-child
		padding-top: 0

	.commentary-modal .commentary-text p:last-child
		padding-bottom: 0

	.commentary-pane .commentary-text p:last-child
		padding-bottom: 0

	.commentary-modal .commentary-text [data-block-idx]
		cursor: pointer

	.commentary-pane .commentary-text [data-block-idx]
		cursor: pointer
