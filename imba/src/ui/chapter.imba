import GenericReader from '../lib/GenericReader'
import activities from '../lib/Activities'
import { canvasLineDash, freehandWrapClose, freehandWrapOpen } from '../lib/highlightStyles'

import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import Bookmark from 'lucide-static/icons/bookmark.svg'
import Link2 from 'lucide-static/icons/link-2.svg'
import SettingsIcon from 'lucide-static/icons/settings.svg'
import X from 'lucide-static/icons/x.svg'
import * as ICONS from 'imba-phosphor-icons'

import { hasTouchEvents, translationNames } from '../constants'

tag chapter < section
	prop me\(GenericReader)
	prop headerFontSize = 2 # rem
	prop versePrefix = ''
	minHeaderFont = 0 # rem

	get liftShift
		const raw = versePrefix == 'p' ? activities.parallelLiftShift : activities.mainLiftShift
		if raw > 240
			return 240
		if raw < 0
			return 0
		return raw

	get extraBottomPad
		if liftShift > 0
			return 0
		return activities.bottomBarReserve

	get main
		return document.getElementById "main"

	def isChapterVerseId id\string
		unless id
			return no
		if versePrefix == 'p'
			return !!id.match(/^p\d+$/)
		return !!id.match(/^\d+$/)

	def calculateTopVerse e\Event
		if activities.scrollLockTimeout != null
			if activities.blockInScroll != self
				return

			clearTimeout(activities.scrollLockTimeout)

		activities.blockInScroll = self
		activities.scrollLockTimeout = setTimeout(&, 1000) do
			activities.blockInScroll = null
			activities.scrollLockTimeout = null

		const destScroller = versePrefix == 'p' ? reader.myRenderer : parallelReader.myRenderer
		if self.scrollTop <= 4
			if destScroller and destScroller.scrollTop > 0
				destScroller.scrollTop = 0
			return

		const article = self.querySelector('article')
		unless article
			return

		const viewTop = self.getBoundingClientRect().top
		let topEl = null
		const nodes = article.querySelectorAll('span[id]')
		for el in nodes
			const id = String(el.id or '')
			unless isChapterVerseId(id)
				continue
			if el.getBoundingClientRect().top <= viewTop + 56
				topEl = el

		unless topEl
			for el in nodes
				const id = String(el.id or '')
				if isChapterVerseId(id)
					topEl = el
					break

		unless topEl
			return
		const numeric = String(topEl.id).match(/\d+/)
		unless numeric
			return
		const offset = topEl.getBoundingClientRect().top - viewTop
		if versePrefix == 'p'
			reader.scrollVerseToTop(numeric[0], offset)
		else
			parallelReader.scrollVerseToTop(numeric[0], offset)

	def changeHeadersSizeOnScroll e\Event
		if e.target != self
			return
		if settings.parallel_sync and parallelReader.enabled
			calculateTopVerse e
		if dictionary.tooltip
			self.dictionary.showTooltip!

	def enlargeHeader
		return

	def shrinkHeader
		return

	def isMyRect matchId\string
		if activities.activeModal != ''
			return no
		if !matchId
			return no
		if versePrefix == ''
			# Main reader verse ids are numeric-only.
			return !matchId.match(/[a-zA-Z]/)
		return matchId.startsWith(versePrefix)
	
	@observable dragging = no
	currentDragHighlight = null
	freehandStrokeCanvas = null
	freehandStrokeCtx = null
	freehandStrokeDrawing = no
	freehandStrokePoints = []
	freehandStrokeStartedAt = 0
	freehandMoveDebugCount = 0
	freehandSelectionAnchor = null
	freehandSelectionFocus = null
	globalPointerMoveHandler = null
	globalPenMoveHandler = null
	penDrawing = no
	currentPenStroke = null
	globalPointerUpHandler = null
	globalPointerCancelHandler = null
	globalMouseUpHandler = null
	globalTouchEndHandler = null
	globalTouchCancelHandler = null
	stylusHighlightActive = no
	stylusEraseActive = no
	stylusGuardUntil = 0
	stylusContextMenuHandler = null
	stylusSelectGuardHandler = null
	lastPenSeenAt = 0

	get highlightArmed
		return activities.freehandHighlightMode or stylusHighlightActive

	get eraseArmed
		return activities.freehandEraserMode or stylusEraseActive

	get drawingArmed
		return activities.freehandHighlightMode or activities.penToolMode or stylusHighlightActive or stylusEraseActive

	get highlightPreviewColor
		if stylusHighlightActive
			const color = activities.freehandHighlightColor or ''
			if color == '#000000' or color == '#DC2626'
				return '#F9E2A0'
		return activities.freehandHighlightColor or '#eab308'

	def isPenPointer e
		return e and e.pointerType == 'pen'

	def isPenInContact e
		unless e
			return no
		if (e.buttons & 1) != 0 or (e.buttons & 32) != 0
			return yes
		if typeof e.pressure == 'number' and e.pressure > 0.05
			return yes
		return no

	def isPenContactLost e
		unless e
			return no
		unless isPenPointer(e)
			return no
		if e.buttons != 0
			return no
		if typeof e.pressure == 'number' and e.pressure > 0.05
			return no
		return yes

	def shouldStartStylusStroke e
		unless e
			return no
		if dragging
			return no
		if isPenEraser(e)
			return yes
		if isPenBarrel(e) and (e.type == 'pointerdown' or isPenInContact(e))
			return yes
		return no

	def recentlyUsedPen
		return (Date.now() - lastPenSeenAt) < 1500

	def rememberPen e
		unless e
			return
		if e.pointerType == 'pen'
			lastPenSeenAt = Date.now()
			activities.lastPenSeenAt = lastPenSeenAt
			if self and self.style
				self.style.touchAction = 'none'

	def isPenBarrel e
		unless e
			return no
		const barrel = e.button == 2 or (e.buttons & 2) != 0
		unless barrel
			return no
		if isPenPointer(e) or recentlyUsedPen
			return yes
		return no

	def isPenEraser e
		unless e
			return no
		if e.button == 5 or (e.buttons & 32) != 0
			return isPenPointer(e) or recentlyUsedPen
		return no

	def clearStylusOverrides
		stylusHighlightActive = no
		stylusEraseActive = no
		activities.stylusDrawing = no
		stopStylusSelectGuard!

	def startStylusSelectGuard
		unless stylusSelectGuardHandler
			stylusSelectGuardHandler = do |ev|
				if ev and ev.preventDefault
					ev.preventDefault()
				return no
			document.addEventListener('selectstart', stylusSelectGuardHandler, true)
			document.addEventListener('dragstart', stylusSelectGuardHandler, true)

	def stopStylusSelectGuard
		if stylusSelectGuardHandler
			document.removeEventListener('selectstart', stylusSelectGuardHandler, true)
			document.removeEventListener('dragstart', stylusSelectGuardHandler, true)
			stylusSelectGuardHandler = null
		try
			window.getSelection().removeAllRanges()
		catch err
			pass

	def suppressPenBrowserGesture e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()

	def handleContextMenu e
		rememberPen(e)
		const fromPen = isPenPointer(e) or isPenBarrel(e) or recentlyUsedPen or stylusHighlightActive or stylusEraseActive or Date.now() < stylusGuardUntil
		unless fromPen
			return no
		suppressPenBrowserGesture(e)
		return yes

	def handleAuxClick e
		rememberPen(e)
		unless isPenBarrel(e) or recentlyUsedPen
			return
		suppressPenBrowserGesture(e)

	def getRawPointerSnapshot e
		let touch = e && e.touches && e.touches.length ? e.touches[0] : (e && e.changedTouches && e.changedTouches.length ? e.changedTouches[0] : null)
		return {
			type: e and e.type ? e.type : null
			clientX: touch ? touch.clientX : (e and typeof e.clientX == 'number' ? e.clientX : null)
			clientY: touch ? touch.clientY : (e and typeof e.clientY == 'number' ? e.clientY : null)
			x: e and typeof e.x == 'number' ? e.x : null
			y: e and typeof e.y == 'number' ? e.y : null
			pageX: e and typeof e.pageX == 'number' ? e.pageX : null
			pageY: e and typeof e.pageY == 'number' ? e.pageY : null
			scrollTop: self ? self.scrollTop : null
			scrollLeft: self ? self.scrollLeft : null
		}

	def getPointerCoords e
		let touch = e && e.touches && e.touches.length ? e.touches[0] : (e && e.changedTouches && e.changedTouches.length ? e.changedTouches[0] : null)
		let clientX = null
		let clientY = null
		if touch
			clientX = touch.clientX
			clientY = touch.clientY
		else
			if e && typeof e.clientX == 'number' and typeof e.clientY == 'number'
				clientX = e.clientX
				clientY = e.clientY
			elif e && typeof e.x == 'number' and typeof e.y == 'number'
				clientX = e.x
				clientY = e.y
			elif e && typeof e.pageX == 'number' and typeof e.pageY == 'number'
				clientX = e.pageX - (window.scrollX or 0)
				clientY = e.pageY - (window.scrollY or 0)
		if clientX == null or clientY == null
			console.log('[FREEHAND DEBUG] missing pointer coords', getRawPointerSnapshot(e))
			return null
		let rect = self.getBoundingClientRect()
		return {
			x: Math.max(0, clientX - rect.left + self.scrollLeft)
			y: Math.max(0, clientY - rect.top + self.scrollTop)
		}

	def getClientPoint e
		let touch = e && e.touches && e.touches.length ? e.touches[0] : (e && e.changedTouches && e.changedTouches.length ? e.changedTouches[0] : null)
		if touch
			return { x: touch.clientX, y: touch.clientY }
		if e && typeof e.clientX == 'number' and typeof e.clientY == 'number'
			return { x: e.clientX, y: e.clientY }
		return null

	def getVerseAnchorElementFromEvent e
		const point = getClientPoint(e)
		let el = null
		if point
			el = document.elementFromPoint(point.x, point.y)
		if !el and e and e.target
			el = e.target
		while el
			if el.id and (el.id.match(/^\d+$/) or el.id.match(/^p\d+$/))
				return el
			el = el.parentElement
		let fallback = null
		let minDistance = 999999
		for verseEl in self.querySelectorAll('span[id]')
			const r = verseEl.getBoundingClientRect()
			const centerY = r.top + r.height / 2
			const d = point ? Math.abs(centerY - point.y) : 0
			if d < minDistance
				minDistance = d
				fallback = verseEl
		return fallback

	def getElementCoordsInSelf el
		if !el
			return { x: 0, y: 0 }
		const rect = el.getBoundingClientRect()
		const selfRect = self.getBoundingClientRect()
		return {
			x: rect.left - selfRect.left + self.scrollLeft
			y: rect.top - selfRect.top + self.scrollTop
		}

	def getPenStrokeBase stroke
		if !stroke
			return { x: 0, y: 0 }
		const anchorEl = stroke.anchorId ? document.getElementById(stroke.anchorId) : null
		if anchorEl
			const anchorPos = getElementCoordsInSelf(anchorEl)
			return {
				x: anchorPos.x + (stroke.anchorDx or 0)
				y: anchorPos.y + (stroke.anchorDy or 0)
			}
		return {
			x: stroke.fallbackBaseX or 0
			y: stroke.fallbackBaseY or 0
		}

	def getDrawingSurfaceWidth
		# Keep drawing surface width tied to viewport width to avoid recursive scroll growth.
		const width = Math.max(self.clientWidth or 0, 1)
		return Math.min(width, 8192)

	def getDrawingSurfaceHeight
		const article = self.querySelector('article')
		if article
			return Math.max(article.offsetTop + article.offsetHeight, 1)
		return Math.max(self.clientHeight or 0, 1)

	def pointToSegmentDistance px, py, x1, y1, x2, y2
		const dx = x2 - x1
		const dy = y2 - y1
		if dx == 0 and dy == 0
			const ddx = px - x1
			const ddy = py - y1
			return Math.sqrt(ddx * ddx + ddy * ddy)
		let t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy)
		t = Math.max(0, Math.min(1, t))
		const projX = x1 + t * dx
		const projY = y1 + t * dy
		const ddx = px - projX
		const ddy = py - projY
		return Math.sqrt(ddx * ddx + ddy * ddy)

	def strokeIntersectsPoint stroke, point, radius\number
		if !stroke or !stroke.points or stroke.points.length == 0
			return no
		const base = getPenStrokeBase(stroke)
		const widthRadius = Math.max(2, (stroke.width or 6) / 2)
		const hitRadius = radius + widthRadius
		if stroke.points.length == 1
			const x = base.x + stroke.points[0].x
			const y = base.y + stroke.points[0].y
			const dx = point.x - x
			const dy = point.y - y
			return Math.sqrt(dx * dx + dy * dy) <= hitRadius
		for pointItem, index in stroke.points
			if index == 0
				continue
			const prev = stroke.points[index - 1]
			const x1 = base.x + prev.x
			const y1 = base.y + prev.y
			const x2 = base.x + pointItem.x
			const y2 = base.y + pointItem.y
			if pointToSegmentDistance(point.x, point.y, x1, y1, x2, y2) <= hitRadius
				return yes
		return no

	def erasePenAtPoint e
		let p = getPointerCoords(e)
		return unless p
		const existing = activities.getPenSketchesFor(me.translation, me.book, me.chapter)
		if !existing or existing.length == 0
			return
		const keep = existing.filter(do |stroke|
			return !strokeIntersectsPoint(stroke, p, 14)
		)
		if keep.length != existing.length
			console.log('[PEN DEBUG] erased strokes', {
				before: existing.length,
				after: keep.length,
				removed: existing.length - keep.length
			})
			activities.setPenSketchesFor(me.translation, me.book, me.chapter, keep)

	def ensureFreehandStrokeCanvas
		let canvas = freehandStrokeCanvas or self.querySelector('.freehand-stroke-canvas')
		return unless canvas
		let width = getDrawingSurfaceWidth!
		let height = getDrawingSurfaceHeight!
		let ratio = window.devicePixelRatio or 1
		canvas.style.top = "0px"
		canvas.style.left = "0px"
		canvas.style.width = "{width}px"
		canvas.style.height = "{height}px"
		canvas.width = Math.floor(width * ratio)
		canvas.height = Math.floor(height * ratio)
		let ctx = canvas.getContext('2d')
		return unless ctx
		ctx.setTransform(1, 0, 0, 1, 0, 0)
		ctx.scale(ratio, ratio)
		ctx.lineJoin = 'round'
		ctx.lineCap = 'round'
		if activities.patternHighlightMode
			ctx.lineWidth = 3
			ctx.setLineDash(canvasLineDash(activities.underlineStyle))
		else
			# Keep preview stroke visually close to final applied block size.
			ctx.lineWidth = 24
			ctx.setLineDash([])
		ctx.strokeStyle = highlightPreviewColor
		# Keep preview color identical to applied color.
		ctx.globalAlpha = 1
		freehandStrokeCanvas = canvas
		freehandStrokeCtx = ctx

	def clearFreehandStrokeCanvas
		if freehandStrokeCtx and freehandStrokeCanvas
			let width = getDrawingSurfaceWidth!
			let height = getDrawingSurfaceHeight!
			freehandStrokeCtx.clearRect(0, 0, width, height)
		freehandStrokeDrawing = no
		freehandStrokePoints = []

	def redrawFreehandStrokePreview
		# Underline mode draws straight onto the text, so no canvas preview.
		return if activities.patternHighlightMode
		return unless freehandStrokeCtx and freehandStrokeCanvas
		let width = getDrawingSurfaceWidth!
		let height = getDrawingSurfaceHeight!
		freehandStrokeCtx.clearRect(0, 0, width, height)
		return unless freehandStrokePoints.length
		freehandStrokeCtx.beginPath!
		freehandStrokeCtx.moveTo(freehandStrokePoints[0].x, freehandStrokePoints[0].y)
		for point, index in freehandStrokePoints
			if index == 0
				continue
			freehandStrokeCtx.lineTo(point.x, point.y)
		freehandStrokeCtx.stroke!

	def beginFreehandStroke e
		return unless highlightArmed or eraseArmed
		let p = getPointerCoords(e)
		return unless p
		freehandStrokePoints = [p]
		freehandStrokeDrawing = yes
		freehandStrokeStartedAt = Date.now()
		freehandMoveDebugCount = 0
		unless activities.patternHighlightMode
			ensureFreehandStrokeCanvas!
			return unless freehandStrokeCtx
			redrawFreehandStrokePreview!

	def drawFreehandStroke e
		return unless freehandStrokeDrawing
		let p = getPointerCoords(e)
		return unless p
		freehandStrokePoints.push(p)
		return if activities.patternHighlightMode
		return unless freehandStrokeCtx
		redrawFreehandStrokePreview!

	def endFreehandStroke
		freehandStrokeStartedAt = 0
		freehandSelectionAnchor = null
		freehandSelectionFocus = null
		freehandStrokeDrawing = no
		freehandStrokePoints = []
		if activities.patternHighlightMode
			return
		if freehandStrokeCtx and freehandStrokeCanvas
			let width = getDrawingSurfaceWidth!
			let height = getDrawingSurfaceHeight!
			freehandStrokeCtx.clearRect(0, 0, width, height)

	def beginPenStroke e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if activities.penEraserMode
			penDrawing = yes
			currentPenStroke = null
			erasePenAtPoint(e)
			startPenDragListeners!
			return
		let p = getPointerCoords(e)
		return unless p
		const anchorEl = getVerseAnchorElementFromEvent(e)
		const anchorId = anchorEl ? anchorEl.id : null
		const anchorPos = getElementCoordsInSelf(anchorEl)
		currentPenStroke = {
			id: "pen-{Date.now()}-{Math.floor(Math.random() * 100000)}"
			color: activities.freehandHighlightColor or '#000000'
			width: activities.penLineWidth or 6
			anchorId: anchorId
			anchorDx: p.x - anchorPos.x
			anchorDy: p.y - anchorPos.y
			fallbackBaseX: p.x
			fallbackBaseY: p.y
			points: [{ x: 0, y: 0 }]
			date: Date.now()
		}
		penDrawing = yes
		startPenDragListeners!
		imba.commit!

	def drawPenStroke e
		return unless penDrawing
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if activities.penEraserMode
			erasePenAtPoint(e)
			return
		return unless currentPenStroke
		let p = getPointerCoords(e)
		return unless p
		const base = getPenStrokeBase(currentPenStroke)
		currentPenStroke.points.push({
			x: p.x - base.x
			y: p.y - base.y
		})
		imba.commit!

	def endPenStroke
		return unless penDrawing
		stopPenDragListeners!
		penDrawing = no
		if activities.penEraserMode
			currentPenStroke = null
			return
		const stroke = currentPenStroke
		currentPenStroke = null
		if stroke and stroke.points and stroke.points.length > 1
			activities.addPenSketch(me.translation, me.book, me.chapter, stroke)
		imba.commit!

	def finalizeFreehandStroke
		if penDrawing
			endPenStroke!
			clearStylusOverrides!
			return
		return unless dragging
		dragging = no
		stopFreehandDragListeners!
		applySelectionFromStrokePoints!
		commitFreehandHighlightFromStrokePoints(yes)
		endFreehandStroke!
		window.getSelection().removeAllRanges()
		me.refreshFreehandHighlightDisplay!
		clearStylusOverrides!
		imba.commit!

	@autorun def resetFreehandCanvasOnChapterChange
		const _t = me.translation
		const _b = me.book
		const _c = me.chapter
		clearFreehandStrokeCanvas!

	def clientPointFromChapterPoint p
		let rect = self.getBoundingClientRect()
		return {
			x: rect.left + p.x - self.scrollLeft
			y: rect.top + p.y - self.scrollTop
		}

	def buildRangeBetween anchor, focus
		let liveRange = document.createRange()
		let cmp = anchor.compareBoundaryPoints(Range.START_TO_START, focus)
		if cmp <= 0
			liveRange.setStart(anchor.startContainer, anchor.startOffset)
			liveRange.setEnd(focus.startContainer, focus.startOffset)
		else
			liveRange.setStart(focus.startContainer, focus.startOffset)
			liveRange.setEnd(anchor.startContainer, anchor.startOffset)
		return liveRange

	def applySelectionFromStrokePoints
		return unless highlightArmed
		return if eraseArmed
		return unless freehandStrokePoints.length
		let startRange = null
		let endRange = null
		for point in freehandStrokePoints
			let client = clientPointFromChapterPoint(point)
			let range = getCaretRangeFromClientPoint(client.x, client.y)
			continue unless range
			if !startRange
				startRange = range
				endRange = range
			else
				if range.compareBoundaryPoints(Range.START_TO_START, startRange) < 0
					startRange = range
				if range.compareBoundaryPoints(Range.START_TO_START, endRange) > 0
					endRange = range
		return unless startRange and endRange
		let liveRange = buildRangeBetween(startRange, endRange)
		let selection = window.getSelection()
		selection.removeAllRanges()
		selection.addRange(liveRange)

	def startFreehandDragListeners
		stopFreehandDragListeners!
		globalPointerMoveHandler = do |ev|
			return unless dragging and (highlightArmed or eraseArmed)
			if isPenContactLost(ev)
				finalizeFreehandStroke!
				return
			if ev and ev.preventDefault
				ev.preventDefault()
			if eraseArmed
				erasePenAtPoint(ev)
			drawFreehandStroke(ev)
			unless eraseArmed
				updateFreehandTextSelection(ev, no)
			commitFreehandHighlightFromStrokePoints(no)
		window.addEventListener('pointermove', globalPointerMoveHandler, { passive: false })
		window.addEventListener('touchmove', globalPointerMoveHandler, { passive: false })

	def stopFreehandDragListeners
		if globalPointerMoveHandler
			window.removeEventListener('pointermove', globalPointerMoveHandler)
			window.removeEventListener('touchmove', globalPointerMoveHandler)
			globalPointerMoveHandler = null

	def startPenDragListeners
		stopPenDragListeners!
		globalPenMoveHandler = do |ev|
			if ev and (isPenBarrel(ev) or isPenEraser(ev))
				convertPenStrokeToStylus(ev)
				return
			return unless penDrawing and activities.penToolMode
			if ev and ev.preventDefault
				ev.preventDefault()
			drawPenStroke(ev)
		window.addEventListener('pointermove', globalPenMoveHandler, { passive: false })
		window.addEventListener('touchmove', globalPenMoveHandler, { passive: false })

	def stopPenDragListeners
		if globalPenMoveHandler
			window.removeEventListener('pointermove', globalPenMoveHandler)
			window.removeEventListener('touchmove', globalPenMoveHandler)
			globalPenMoveHandler = null

	def getCaretRangeFromClientPoint clientX, clientY
		let range = null
		if document.caretRangeFromPoint
			range = document.caretRangeFromPoint(clientX, clientY)
		elif document.caretPositionFromPoint
			let pos = document.caretPositionFromPoint(clientX, clientY)
			if pos and pos.offsetNode
				range = document.createRange()
				range.setStart(pos.offsetNode, pos.offset)
				range.collapse(yes)
		return unless range
		let article = self.querySelector('article')
		if article
			let node = range.startContainer
			if node.nodeType == 3
				node = node.parentElement
			if node and !article.contains(node)
				return null
		return range

	def updateFreehandTextSelection e, isAnchor = no
		return unless highlightArmed or eraseArmed
		let point = getClientPoint(e)
		return unless point
		let range = getCaretRangeFromClientPoint(point.x, point.y)
		return unless range
		let selection = window.getSelection()
		if isAnchor
			freehandSelectionAnchor = range.cloneRange()
			freehandSelectionFocus = range.cloneRange()
			selection.removeAllRanges()
			selection.addRange(freehandSelectionAnchor.cloneRange())
		else
			return unless freehandSelectionAnchor
			freehandSelectionFocus = range.cloneRange()
			try
				let liveRange = buildRangeBetween(freehandSelectionAnchor, freehandSelectionFocus)
				selection.removeAllRanges()
				selection.addRange(liveRange)
			catch err
				# ignore invalid cross-node range errors while dragging

	def capturePointer e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if typeof e.pointerId == 'number'
			try
				if self.setPointerCapture
					self.setPointerCapture(e.pointerId)
			catch err
				# ignore if capture fails

	def startStylusStroke e, kind = null
		if dragging and (stylusHighlightActive or stylusEraseActive)
			return
		stylusGuardUntil = Date.now() + 2000
		activities.stylusDrawing = yes
		const erase = kind == 'erase' or (kind != 'highlight' and isPenBarrel(e))
		if erase
			stylusEraseActive = yes
			stylusHighlightActive = no
		else
			stylusHighlightActive = yes
			stylusEraseActive = no
		console.log('[PEN] stylus stroke', {
			kind: erase ? 'erase' : 'highlight'
			type: e and e.type
			pointerType: e and e.pointerType
			button: e and e.button
			buttons: e and e.buttons
		})
		unless stylusContextMenuHandler
			stylusContextMenuHandler = do |ev| handleContextMenu(ev)
			window.addEventListener('contextmenu', stylusContextMenuHandler, true)
		startStylusSelectGuard!
		capturePointer(e)
		dragging = yes
		currentDragHighlight = null
		beginFreehandStroke(e)
		if erase
			try
				window.getSelection().removeAllRanges()
			catch err
				pass
		else
			updateFreehandTextSelection(e, yes)
		startFreehandDragListeners!
		if stylusEraseActive
			erasePenAtPoint(e)

	def convertPenStrokeToStylus e
		stopPenDragListeners!
		penDrawing = no
		currentPenStroke = null
		startStylusStroke(e)

	def handlePointerDown e
		rememberPen(e)
		if isPenBarrel(e)
			suppressPenBrowserGesture(e)
			startStylusStroke(e, 'erase')
			return
		if isPenEraser(e)
			suppressPenBrowserGesture(e)
			startStylusStroke(e, 'highlight')
			return
		if activities.penToolMode
			capturePointer(e)
			beginPenStroke(e)
		elif activities.freehandHighlightMode
			capturePointer(e)
			dragging = yes
			currentDragHighlight = null
			beginFreehandStroke(e)
			updateFreehandTextSelection(e, yes)
			startFreehandDragListeners!

	def handlePointerUp e
		finalizeFreehandStroke!

	def handlePointerMove e
		rememberPen(e)
		if dragging and (highlightArmed or eraseArmed) and isPenContactLost(e)
			finalizeFreehandStroke!
			return
		if e and (isPenBarrel(e) or isPenEraser(e))
			if penDrawing
				convertPenStrokeToStylus(e)
				return
			if shouldStartStylusStroke(e)
				startStylusStroke(e)
				return
		if penDrawing and activities.penToolMode
			if e and e.preventDefault
				e.preventDefault()
			drawPenStroke(e)
		elif dragging and (highlightArmed or eraseArmed)
			if e and e.preventDefault
				e.preventDefault()
			if eraseArmed
				erasePenAtPoint(e)
			drawFreehandStroke(e)
			unless eraseArmed
				updateFreehandTextSelection(e, no)

	def mount
		globalPointerUpHandler = do finalizeFreehandStroke!
		globalPointerCancelHandler = do finalizeFreehandStroke!
		globalMouseUpHandler = do finalizeFreehandStroke!
		globalTouchEndHandler = do finalizeFreehandStroke!
		globalTouchCancelHandler = do finalizeFreehandStroke!
		window.addEventListener('pointerup', globalPointerUpHandler)
		window.addEventListener('pointercancel', globalPointerCancelHandler)
		window.addEventListener('mouseup', globalMouseUpHandler)
		window.addEventListener('touchend', globalTouchEndHandler)
		window.addEventListener('touchcancel', globalTouchCancelHandler)
		unless stylusContextMenuHandler
			stylusContextMenuHandler = do |ev| handleContextMenu(ev)
			window.addEventListener('contextmenu', stylusContextMenuHandler, true)

	def unmount
		stopFreehandDragListeners!
		stopPenDragListeners!
		clearStylusOverrides!
		if stylusContextMenuHandler
			window.removeEventListener('contextmenu', stylusContextMenuHandler, true)
			stylusContextMenuHandler = null
		if globalPointerUpHandler
			window.removeEventListener('pointerup', globalPointerUpHandler)
			globalPointerUpHandler = null
		if globalPointerCancelHandler
			window.removeEventListener('pointercancel', globalPointerCancelHandler)
			globalPointerCancelHandler = null
		if globalMouseUpHandler
			window.removeEventListener('mouseup', globalMouseUpHandler)
			globalMouseUpHandler = null
		if globalTouchEndHandler
			window.removeEventListener('touchend', globalTouchEndHandler)
			globalTouchEndHandler = null
		if globalTouchCancelHandler
			window.removeEventListener('touchcancel', globalTouchCancelHandler)
			globalTouchCancelHandler = null
		
	def getCharOffsetInVerseSpan node, offset, root
		let count = 0
		let walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false)
		while (let next = walker.nextNode())
			if next == node
				return count + offset
			count += next.textContent.length
		return count

	def getTextPositionFromRangePoint container, offset
		let parent = container and container.nodeType == 3 ? container.parentElement : container
		return unless parent
		let span = parent.closest('span[id]')
		return unless span
		let article = self.querySelector('article')
		if article and !article.contains(span)
			return null
		let verse = parseInt(span.id.replace(versePrefix, ''))
		if Number.isNaN(verse)
			return null
		let charOffset = getCharOffsetInVerseSpan(container, offset, span)
		return {
			verse: verse
			offset: charOffset
			pos: verse * 1000000 + charOffset
		}

	def getVerseSpanFromClientPoint clientX, clientY
		let article = self.querySelector('article')
		return unless article
		let candidates = []
		if document.elementsFromPoint
			candidates = document.elementsFromPoint(clientX, clientY)
		elif document.elementFromPoint
			let one = document.elementFromPoint(clientX, clientY)
			if one
				candidates = [one]
		for el in candidates
			continue unless el
			let node = el.nodeType == 3 ? el.parentElement : el
			continue unless node and node.closest
			let span = node.closest('span[id]')
			if span and article.contains(span) and isChapterVerseId(String(span.id or ''))
				return span
		let nodes = article.querySelectorAll('span[id]')
		let best = null
		let bestDist = 40 * 40
		for span in nodes
			continue unless isChapterVerseId(String(span.id or ''))
			let rect = span.getBoundingClientRect()
			if clientX >= rect.left and clientX <= rect.right and clientY >= rect.top and clientY <= rect.bottom
				return span
			let dx = 0
			if clientX < rect.left
				dx = rect.left - clientX
			elif clientX > rect.right
				dx = clientX - rect.right
			let dy = 0
			if clientY < rect.top
				dy = rect.top - clientY
			elif clientY > rect.bottom
				dy = clientY - rect.bottom
			let dist = dx * dx + dy * dy
			if dist < bestDist
				bestDist = dist
				best = span
		return best

	def getTextPositionByHitTestingSpan span, clientX, clientY
		unless span
			return null
		let verse = parseInt(span.id.replace(versePrefix, ''))
		if Number.isNaN(verse)
			return null
		let walker = document.createTreeWalker(span, NodeFilter.SHOW_TEXT, null, false)
		let bestOff = 0
		let bestDist = Infinity
		let offset = 0
		let found = no
		while (let node = walker.nextNode())
			let text = node.textContent or ''
			let len = text.length
			if len == 0
				continue
			let step = len > 96 ? 4 : 1
			let i = 0
			while i <= len
				let range = document.createRange()
				range.setStart(node, i)
				range.collapse(yes)
				let rect = range.getBoundingClientRect()
				let dx = clientX - rect.left
				let dy = clientY - (rect.top + rect.height / 2)
				let dist = dx * dx + dy * dy
				if dist < bestDist
					bestDist = dist
					bestOff = offset + i
					found = yes
				i += step
			offset += len
		unless found
			return {
				verse: verse
				offset: 0
				pos: verse * 1000000
			}
		return {
			verse: verse
			offset: bestOff
			pos: verse * 1000000 + bestOff
		}

	def getTextPositionFromClientPoint clientX, clientY, allowFallback = no
		let range = getCaretRangeFromClientPoint(clientX, clientY)
		if range
			let pos = getTextPositionFromRangePoint(range.startContainer, range.startOffset)
			if pos
				return pos
		unless allowFallback
			return null
		let span = getVerseSpanFromClientPoint(clientX, clientY)
		return getTextPositionByHitTestingSpan(span, clientX, clientY)

	def collectTextPositionsFromStrokePoints allowFallback = no
		let startPos = null
		let endPos = null
		def considerPosition pos
			return unless pos
			if !startPos or pos.pos < startPos.pos
				startPos = pos
			if !endPos or pos.pos > endPos.pos
				endPos = pos
		for point in freehandStrokePoints
			let client = clientPointFromChapterPoint(point)
			considerPosition(getTextPositionFromClientPoint(client.x, client.y, no))
		if startPos and endPos
			return { startPos: startPos, endPos: endPos }
		unless allowFallback
			return { startPos: startPos, endPos: endPos }
		let samples = []
		if freehandStrokePoints.length
			samples.push(freehandStrokePoints[0])
			samples.push(freehandStrokePoints[freehandStrokePoints.length - 1])
			if freehandStrokePoints.length > 2
				samples.push(freehandStrokePoints[Math.floor(freehandStrokePoints.length / 2)])
		for point in samples
			let client = clientPointFromChapterPoint(point)
			considerPosition(getTextPositionFromClientPoint(client.x, client.y, yes))
		return { startPos: startPos, endPos: endPos }

	def applyFreehandHighlightRange startVerse, startOffset, endVerse, endOffset, isFinal = no
		let sPos = startVerse * 1000000 + startOffset
		let ePos = endVerse * 1000000 + endOffset
		if ePos < sPos
			let tmpVerse = startVerse
			let tmpOffset = startOffset
			startVerse = endVerse
			startOffset = endOffset
			endVerse = tmpVerse
			endOffset = tmpOffset
			sPos = startVerse * 1000000 + startOffset
			ePos = endVerse * 1000000 + endOffset

		if eraseArmed
			let newHighlights = []
			let changed = no
			for h in me.freehandHighlights
				let hStart = h.startVerse * 1000000 + h.startOffset
				let hEnd = h.endVerse * 1000000 + h.endOffset
				if ePos < hStart or sPos > hEnd
					newHighlights.push(h)
					continue
				changed = yes
				if hStart < sPos
					newHighlights.push({
						startVerse: h.startVerse
						startOffset: h.startOffset
						endVerse: Math.floor(sPos / 1000000)
						endOffset: sPos % 1000000
						color: h.color
						decoration: h.decoration or 'fill'
						underlineStyle: h.underlineStyle or 'solid'
						date: h.date or Date.now()
					})
				if hEnd > ePos
					newHighlights.push({
						startVerse: Math.floor(ePos / 1000000)
						startOffset: ePos % 1000000
						endVerse: h.endVerse
						endOffset: h.endOffset
						color: h.color
						decoration: h.decoration or 'fill'
						underlineStyle: h.underlineStyle or 'solid'
						date: h.date or Date.now()
					})
			if changed
				me.freehandHighlights = newHighlights
				if isFinal
					me.saveFreehandHighlights!
		else
			const now = Date.now()
			let decoration = activities.patternHighlightMode ? 'underline' : 'fill'
			let highlight = {
				startVerse: startVerse
				startOffset: startOffset
				endVerse: endVerse
				endOffset: endOffset
				color: highlightPreviewColor
				decoration: decoration
				underlineStyle: activities.underlineStyle or 'solid'
				date: now
			}
			if currentDragHighlight
				me.freehandHighlights[me.freehandHighlights.length - 1] = highlight
			else
				me.freehandHighlights.push(highlight)
			currentDragHighlight = isFinal ? null : highlight
			if isFinal
				me.saveFreehandHighlights!
		imba.commit!

	def commitFreehandHighlightFromStrokePoints isFinal = yes
		return unless highlightArmed or eraseArmed
		return unless freehandStrokePoints.length
		let positions = collectTextPositionsFromStrokePoints(isFinal)
		return unless positions.startPos and positions.endPos
		applyFreehandHighlightRange(positions.startPos.verse, positions.startPos.offset, positions.endPos.verse, positions.endPos.offset, isFinal)

	def handleFreehandHighlight isFinal = no
		return unless highlightArmed or eraseArmed
		
		let selection = window.getSelection()
		if selection.isCollapsed
			if isFinal and currentDragHighlight
				currentDragHighlight = null
			return
		
		let range = selection.getRangeAt(0)
		let startParent = range.startContainer and range.startContainer.nodeType == 1 ? range.startContainer : range.startContainer.parentElement
		let endParent = range.endContainer and range.endContainer.nodeType == 1 ? range.endContainer : range.endContainer.parentElement
		return unless startParent and endParent
		
		let article = startParent.closest('article')
		return unless article
		
		let startSpan = startParent.closest('span[id]')
		let endSpan = endParent.closest('span[id]')
		return unless startSpan and endSpan
		
		let startVerse = parseInt(startSpan.id.replace(versePrefix, ''))
		let endVerse = parseInt(endSpan.id.replace(versePrefix, ''))
		let startOffset = getCharOffsetInVerseSpan(range.startContainer, range.startOffset, startSpan)
		let endOffset = getCharOffsetInVerseSpan(range.endContainer, range.endOffset, endSpan)

		applyFreehandHighlightRange(startVerse, startOffset, endVerse, endOffset, isFinal)
		
		selection.removeAllRanges()
		imba.commit!

	def applyHighlightsToHtml html, highlights
		# Parse the HTML into a list of "parts": either a tag or a text node
		let parts = []
		let i = 0
		while i < html.length
			if html[i] == '<'
				let end = html.indexOf('>', i)
				if end != -1
					parts.push({ type: 'tag', content: html.slice(i, end + 1) })
					i = end + 1
					continue
			let nextTag = html.indexOf('<', i)
			let content = nextTag == -1 ? html.slice(i) : html.slice(i, nextTag)
			parts.push({ type: 'text', content: content })
			i += content.length

		# Sort highlights by start offset ascending
		highlights.sort(do |a, b| return a.start - b.start)

		let result = ""
		let currentChar = 0
		let highlightIndex = 0
		let activeHighlights = []

		for part in parts
			if part.type == 'tag'
				result += part.content
				continue

			let text = part.content
			let textPos = 0

			while textPos < text.length
				# Check for highlights starting here
				while highlightIndex < highlights.length and highlights[highlightIndex].start == currentChar
					let h = highlights[highlightIndex]
					result += freehandWrapOpen(h.color, h.decoration or 'fill', h.underlineStyle or 'solid')
					activeHighlights.push(h)
					highlightIndex++

				# Check for highlights ending here
				let highlightsEnding = activeHighlights.filter(do |h| return h.end == currentChar)
				if highlightsEnding.length > 0
					for j in [0 ... highlightsEnding.length]
						let h = highlightsEnding[j]
						result += freehandWrapClose(h.color, h.decoration or 'fill')
					activeHighlights = activeHighlights.filter(do |h| return h.end != currentChar)
					
					# Re-check for new highlights starting exactly here
					while highlightIndex < highlights.length and highlights[highlightIndex].start == currentChar
						let h = highlights[highlightIndex]
						result += freehandWrapOpen(h.color, h.decoration or 'fill', h.underlineStyle or 'solid')
						activeHighlights.push(h)
						highlightIndex++

				result += text[textPos]
				textPos++
				currentChar++
			
			# Check for highlights ending at the very end of a text node
			let highlightsEndingAtEnd = activeHighlights.filter(do |h| return h.end == currentChar)
			if highlightsEndingAtEnd.length > 0
				for j in [0 ... highlightsEndingAtEnd.length]
					let h = highlightsEndingAtEnd[j]
					result += freehandWrapClose(h.color, h.decoration or 'fill')
				activeHighlights = activeHighlights.filter(do |h| return h.end != currentChar)

		return result

	def getVerseText verse
		let verseText = verse.text
		let relevantHighlights = []
		
		for h in me.freehandHighlights
			let entry = {
				start: h.startOffset
				end: h.endOffset
				color: h.color
				decoration: h.decoration or 'fill'
				underlineStyle: h.underlineStyle or 'solid'
			}
			if h.startVerse == verse.verse and h.endVerse == verse.verse
				relevantHighlights.push(entry)
			elif h.startVerse == verse.verse
				entry.end = 999999
				relevantHighlights.push(entry)
			elif h.endVerse == verse.verse
				entry.start = 0
				relevantHighlights.push(entry)
			elif h.startVerse < verse.verse and h.endVerse > verse.verse
				entry.start = 0
				entry.end = 999999
				relevantHighlights.push(entry)
		
		if relevantHighlights.length > 0
			verseText = self.applyHighlightsToHtml(verseText, relevantHighlights)
		
		return verseText

	def getVerseTextForObsidianExport verse
		let text = getVerseText(verse)
		# Freehand / inline marks are already embedded in getVerseText output.
		if text.indexOf('<mark') >= 0
			return text
		let bookmark = me.getBookmark(verse.pk)
		let color = bookmark and bookmark.color ? String(bookmark.color).trim() : ''
		if color != ''
			return "<mark style=\"background: {color};\">{text}</mark>"
		return text

	def getPenStrokePath stroke
		if !stroke or !stroke.points or stroke.points.length == 0
			return ''
		const base = getPenStrokeBase(stroke)
		let d = "M {Math.round(base.x + stroke.points[0].x)} {Math.round(base.y + stroke.points[0].y)}"
		for point, index in stroke.points
			if index == 0
				continue
			d += " L {Math.round(base.x + point.x)} {Math.round(base.y + point.y)}"
		return d

	def currentChapterPenSketches
		return activities.getPenSketchesFor(me.translation, me.book, me.chapter)

	def render
		<self .parallel=parallelReader.enabled
			@scroll.debounce(50ms)=changeHeadersSizeOnScroll
			@pointerdown=handlePointerDown
			@pointermove=handlePointerMove
			@pointerup=handlePointerUp
			@pointercancel=handlePointerUp
			@lostpointercapture=handlePointerUp
			@contextmenu=handleContextMenu
			@auxclick=handleAuxClick
			dir=translationTextDirection(me.translation)>
			<div.chapter-drawing-surface>
				for rect in pageSearch.rects when isMyRect(rect.matchID) and activities.activeModal == ''
					<.{rect.class} id=rect.matchID [pos:absolute zi:-1 top:{rect.top}px left:{rect.left}px width:{rect.width}px height:{rect.height}px]>
				<canvas.freehand-stroke-canvas>
				<svg.pen-sketch-layer>
					for stroke in currentChapterPenSketches()
						const path = getPenStrokePath(stroke)
						if path != ''
							<path d=path stroke=(stroke.color or '#F9E2A0') stroke-width=(stroke.width or 6) fill="none" stroke-linecap="round" stroke-linejoin="round">
					if currentPenStroke
						const activePath = getPenStrokePath(currentPenStroke)
						if activePath != ''
							<path d=activePath stroke=(currentPenStroke.color or '#F9E2A0') stroke-width=(currentPenStroke.width or 6) fill="none" stroke-linecap="round" stroke-linejoin="round">

			if me.verses..length
				<header @pointerleave=shrinkHeader @pointerenter=enlargeHeader>
					<h1.header-title [lh:1 padding-block:0.2em padding-inline:2.5rem m:0 d@md:flex ai@md:center jc@md:center ta:center w:100% pos:relative box-sizing:border-box font:inherit ff:{theme.fontFamily} fw:{theme.fontWeight + 200} fs:{headerFontSize}em fs@lt-sm:{headerFontSize * 0.85}em]
						title=translationFullName(me.translation)>

						<button.header-action.header-bookmark
							.active=activities.isBookBookmarked(me.translation, me.book, me.chapter)
							@click.stop.prevent=activities.toggleBookBookmark(me.translation, me.book, me.chapter)
							title="Bookmark book">
							<svg src=Bookmark aria-hidden=yes>

						<span.book-title @click=activities.toggleBooksMenu(!!versePrefix)>
							me.nameOfCurrentBook, ' ', me.chapter
							<sup.translation-mark title=translationFullName(me.translation)> me.translation

						<button.header-action.header-settings
							.active=(activities.settingsDrawerOffset == 0)
							@click.stop.prevent=activities.toggleSettingsMenu
							title=t.settings>
							<svg src=SettingsIcon aria-hidden=yes>

			if me.me == 'main'
				<div.tabs-sticky>
					<bible-tabs scale=1>
			<article[text-indent: {settings.verse_number ? 0 : 2.5}em] 
					data-verse-break="{settings.verse_break}"
				[key={(me.translation or '') + ':' + (me.book or 0) + ':' + (me.chapter or 0) + ':' + ((me.verses and me.verses.length) or 0) + ':' + ((me.bookmarks and me.bookmarks.length) or 0)}]
				[mt: 30px]
					[pl: 30px]
					[pr: 30px]
					[position: relative]
					[padding-bottom:{extraBottomPad}px]=(extraBottomPad > 0)
					[transform: translateY({-liftShift}px)]=(liftShift > 0)>
					
					# Verse selection overlay box (matches Obsidian plugin style)
					# Render if this reader has copy-select active (check per-reader PKs)
					let readerType = me.me or ''
					let hasCopySelect = false
					let startPK = 0
					if readerType == 'main'
						hasCopySelect = activities.copySelectMode and activities.copySelectStartPKMain > 0
						startPK = activities.copySelectStartPKMain
					else
						hasCopySelect = activities.copySelectMode and activities.copySelectStartPKParallel > 0
						startPK = activities.copySelectStartPKParallel
					
					if hasCopySelect
						<div.verse-selection-box>
							<button.verse-selection-insert-btn 
								@click.stop.prevent=(do
									# Get selected verses
									let selectedVerses = []
									let versesArr = me.verses or []
									# Use per-reader PKs
									let readerType = me.me or ''
									let startPK = readerType == 'main' ? activities.copySelectStartPKMain : activities.copySelectStartPKParallel
									let endPK = readerType == 'main' ? activities.copySelectEndPKMain : activities.copySelectEndPKParallel
									
									let startIdx = versesArr.findIndex(do |v| return v.pk == startPK)
									let endIdx = versesArr.findIndex(do |v| return v.pk == endPK)
									if startIdx != -1 and endIdx != -1
										let minIdx = Math.min(startIdx, endIdx)
										let maxIdx = Math.max(startIdx, endIdx)
										for i in [minIdx .. maxIdx]
											if versesArr[i]
												let verse = versesArr[i]
												let reference = "{me.nameOfCurrentBook} {me.chapter}:{verse.verse}"
												selectedVerses.push({
													reference: reference,
													text: getVerseTextForObsidianExport(verse)
													verse: verse.verse
												})
									
									# Send message to parent window (Obsidian) if in iframe
									# Always try to send if we have verses - let the parent decide if it wants to handle it
									if selectedVerses.length > 0
										# Include translation, book, and chapter info for building the URL
										# Make sure all fields are explicitly set
										let translationCode = me.translation || ''
										let bookName = me.nameOfCurrentBook || ''
										let chapterNum = me.chapter || 1
										let bookIdNum = me.book || 1
										
										# Create message data object with explicit values - ensure all are set
										# Use object literal to ensure proper serialization
										let firstVerseNum = selectedVerses[0].verse
										let lastVerseNum = selectedVerses[selectedVerses.length - 1].verse
										let blockId = activities.newBlockId()
										let messageData = {
											type: 'bible-verse-selection',
											verses: selectedVerses,
											translation: translationCode,
											book: bookName,
											chapter: chapterNum,
											bookId: bookIdNum,
											blockId: blockId,
											startVerse: firstVerseNum,
											endVerse: lastVerseNum
										}
										
										# Always try to send - let the parent decide if it wants to handle it
										# Use structuredClone or JSON serialization to ensure all properties are included
										let sent = no
										try
											# Create a plain object that will serialize correctly
											let messageToSend = {
												type: String(messageData.type),
												verses: Array.from(messageData.verses),
												translation: String(messageData.translation),
												book: String(messageData.book),
												chapter: Number(messageData.chapter),
												bookId: Number(messageData.bookId),
												blockId: String(messageData.blockId),
												startVerse: Number(messageData.startVerse),
												endVerse: Number(messageData.endVerse)
											}
											window.parent.postMessage(messageToSend, '*')
											sent = yes
										catch error
											sent = no
										# Try sending with JSON serialization as fallback
										if !sent
											try
												let jsonMessage = JSON.parse(JSON.stringify(messageData))
												window.parent.postMessage(jsonMessage, '*')
											catch fallbackError
												pass
								)>
									<svg src=ChevronLeft>
							<button.verse-selection-close-btn 
								@click.stop.prevent=(do
									let readerType = me.me or ''
									
									# Only clear this reader's copy-select, keep the other reader's if it exists
									if readerType == 'main'
										activities.copySelectStartPKMain = 0
										activities.copySelectEndPKMain = 0
										# Clear global PKs only if parallel doesn't have active copy-select
										if activities.copySelectStartPKParallel == 0
											activities.copySelectStartPK = 0
											activities.copySelectEndPK = 0
											activities.copySelectedVersesPKs = []
											activities.copySelectModeReader = null
									else
										activities.copySelectStartPKParallel = 0
										activities.copySelectEndPKParallel = 0
										# Clear global PKs only if main doesn't have active copy-select
										if activities.copySelectStartPKMain == 0
											activities.copySelectStartPK = 0
											activities.copySelectEndPK = 0
											activities.copySelectedVersesPKs = []
											activities.copySelectModeReader = null
									
									imba.commit!
									me.updateCopySelectRange!
								)>
									<svg src=X>
							<span.verse-selection-handle.verse-selection-handle-top 
								@mousedown.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'top'; activities.copySelectReader = me)
								@touchstart.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'top'; activities.copySelectReader = me)>
							<span.verse-selection-handle.verse-selection-handle-bottom 
								@mousedown.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'bottom'; activities.copySelectReader = me)
								@touchstart.prevent.stop=(do activities.copySelectDragging = yes; activities.copySelectDragHandle = 'bottom'; activities.copySelectReader = me)>
					
					for verse, verse_index in (me.verses or [])
						let bookmark = me.getBookmark(verse.pk)
						let bookmarkOnly = me.getBookmarkOnly(verse.pk)
						let noteLinks = me.startVerseNoteLinks(verse.verse)
						let hasNoteLink = noteLinks.length > 0
						let displayCollection = bookmark ? me.stripBookmarkMarker(bookmark.collection) : ''
						let showBookmarkNote = bookmark and (displayCollection or bookmark.note) and not me.nextVerseHasTheSameBookmark(verse_index)
						let superStyle = "scroll-margin-top:1.4rem;"
						let verseText = getVerseText(verse)

						<>
							<span 
								.selected-verse=(activities.selectedVersesPKs.includes(verse.pk)) 
								[background-image: {me.getHighlight(verse.pk)}]
								[color: {activities.selectedVersesPKs.includes(verse.pk) ? null : me.getHighlightTextColor(verse.pk)}]>
								
								if settings.verse_number
									unless settings.verse_break
										<span> ' '
									<span.verse dir="ltr" style=superStyle
										@click=(do
											if drawingArmed
												return
											me.findVerse("{versePrefix}{verse.verse}")
										)>
										<span.verse-number-group>
											<span.verse-marker-slot .has-both=(hasNoteLink and bookmarkOnly) aria-hidden=yes>
												if hasNoteLink and bookmarkOnly
													<button.verse-marker-btn.stacked type="button" @click.stop.prevent=(do me.openVerseNoteLinks(verse.verse)) title="Open Obsidian note">
														<svg.verse-bookmark-icon.verse-link-icon src=Link2 aria-hidden=yes>
														<svg.verse-bookmark-icon width="24" height="24" viewBox="0 0 24 24" fill="#dc2626" stroke="none" aria-hidden=yes>
															<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/>
												elif hasNoteLink
													<button.verse-marker-btn type="button" @click.stop.prevent=(do me.openVerseNoteLinks(verse.verse)) title="Open Obsidian note">
														<svg.verse-bookmark-icon.verse-link-icon src=Link2 aria-hidden=yes>
												elif bookmarkOnly
													if showBookmarkNote
														<note-tooltip compact style=superStyle bookmark=bookmark>
															<svg.verse-bookmark-icon width="24" height="24" viewBox="0 0 24 24" fill="#dc2626" stroke="none" aria-hidden=yes>
																<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/>
													else
														<svg.verse-bookmark-icon width="24" height="24" viewBox="0 0 24 24" fill="#dc2626" stroke="none" aria-hidden=yes>
															<path d="m19 21-7-4-7 4V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v16z"/>
												elif showBookmarkNote
													<note-tooltip compact style=superStyle bookmark=bookmark>
														<svg src=Bookmark aria-hidden=yes>
												else
													<span.verse-marker-spacer aria-hidden=yes>
											<span.verse-number-text>
												if settings.verse_break
													'\u2007'
												verse.verse
												"\u2007"
								else
									unless settings.verse_break
										<span> ' '
								
								<span innerHTML=verseText
									id="{versePrefix}{verse.verse}"
									@click.wait(200ms)=(do
										if drawingArmed
											# During freehand drag, suppress normal verse click selection side effects.
											return
										console.log('[DEBUG] Verse clicked in chapter view:', { pk: verse.pk, verse: verse.verse, prefix: versePrefix })
										me.selectVerse(verse.pk, verse.verse)
									)
									# make it focus-able to get keydown working on it
									tabIndex=0
									@keydown.enter=me.saveBookmark
									[scroll-margin-top: 1.4rem]
								>
							if verse.comment and settings.verse_commentary
								<note-tooltip style=superStyle bookmark=verse.comment>
									<span[c:$acc @hover:$acc-hover]> '†'

							if settings.verse_break
								<br>
								unless settings.verse_number
									<span.ws> '	'
				
			if !me.verses..length
				if !window.navigator.onLine && vault.downloaded_translations.indexOf(me.translation) == -1
					<p.in-offline>
						t.this_translation_is_unavailable
						<br>
						<a.reload @click=(do window.location.reload(yes))> t.reload
				elif not me.loading
					<p.in-offline>
						t.unexisten_chapter
						<br>
						<a.reload @click=(do window.location.reload(yes))> t.reload

			if me.show_verse_picker and settings.verse_picker then <global>
				<section[origin:top left scale@off:0.96 y@off:-1rem o@off:0] ease>
					css
						pos: fixed
						t:3rem l:3rem
						rd:.5rem
						zi:100
						bgc:$bgc
						w:18.75rem mah:86%
						p:.75rem
						rd:1rem
						ofy:auto
						bxs: 0 0 0 1px $acc-bgc-hover, 0 3px 6px $acc-bgc-hover, 0 9px 24px $acc-bgc-hover

						a
							cursor:pointer
							d:inline-block ta:center
							c@hover:$acc-hover
							h:3.375rem w:20%
							fs:1.25rem pt:1rem
							pos:relative

					<[d:flex ai:center]>
						<h2[margin:0 auto lh:1]> t.choose_verse
						<button[c@hover:red4 size:2rem p:.25rem] @click=(me.show_verse_picker=no) title=t.close>
							<svg src=ICONS.X aria-hidden=yes>
					for verse in (me.verses or [])
						<a href="#{versePrefix}{verse.verse}"> verse.verse


	css
		mah: 100vh
		mah: 100svh
		mah@lt-lg: calc(100svh - 2.75rem)
		overflow-y: auto
		overscroll-behavior: contain
		overflow-anchor: none
		-webkit-overflow-scrolling: touch
		w:100% max-width:100%
		pos:relative

		h1
			text-align: center
			margin: 1em 0
			padding: 0
			position: sticky
			background-color: $bgc
			top: 0
			line-height: 1
			cursor: pointer
			word-break: break-word
			padding-inline: 0.25rem

		article
			padding-bottom: 70px
			box-sizing: border-box
			position: relative
			z-index: 0
			transition: transform 0.6s ease

		header
			position: relative
			z-index: 20
			isolation: isolate
			background-color: $bgc
			margin: 0
			padding-top: 1rem
			ta: center
			height: auto

		.header-title
			margin: 0
			overflow: hidden
		
		.book-title
			padding-inline: 0.5rem
			display: inline-block
			cursor: pointer
			touch-action: manipulation

		.translation-mark
			fs: 0.55em
			vertical-align: super
			line-height: 0
			fw: inherit
			c: inherit
			ml: 0.15em
			letter-spacing: 0.02em
			white-space: nowrap
		
		.header-action
			position: absolute
			top: 50%
			transform: translateY(-50%)
			w: 2rem
			h: 2rem
			min-width: 2rem
			p: 0
			bgc: transparent
			c: $acc @hover:$acc-hover
			cursor: pointer
			d: hcc
			rd: 50%
			touch-action: manipulation

			svg
				max-height: 100%
				max-width: 100%
		
		.header-bookmark
			left: 30px
			&.active
				c: #dc2626
				svg
					c: #dc2626
					fill: #dc2626
					stroke: #dc2626
		
		.header-settings
			right: 30px
			&.active
				c: $acc-hover

		.tabs-sticky
			position: sticky
			top: 0
			z-index: 20
			isolation: isolate
			bgc: $bgc
			padding-top: 1rem
			w: 100%
			max-width: 100%
			min-width: 0
			box-sizing: border-box

		section .arrowh
			transition-property: fill, color, background, transform, border-radius

		span
			background-size: 100% 100%
			padding-bottom: .25rem

		.verse
			fs: 0.68em
			c: $acc @hover:$acc-hover
			bgc@hover:$acc-bgc-hover
			vertical-align: baseline
			border-radius: 0.25rem
			padding: 0

		.verse-number-group
			d: inline-flex
			ai: center
			white-space: nowrap
			vertical-align: middle
			text-align: left
			line-height: 1

		.verse-marker-slot
			d: inline-flex
			ai: center
			jc: center
			flex: 0 0 auto
			width: 0.85em
			min-width: 0.85em
			height: 0.85em
			line-height: 1
			overflow: visible
			text-align: center

		.verse-marker-slot.has-both
			height: 1.4em

		.verse-marker-btn
			all: unset
			d: inline-flex
			ai: center
			jc: center
			w: 100%
			h: 100%
			cursor: pointer
			pointer-events: auto
			c: #dc2626

		.verse-marker-btn.stacked
			d: flex
			fld: column
			ai: center
			jc: center
			gap: 0

		.verse-marker-spacer
			d: inline-block
			width: 100%
			height: 100%

		.verse-bookmark-icon
			width: 0.7em
			height: 0.7em
			margin-right: 5px
			pointer-events: none
			d: block
			flex: 0 0 auto

		.verse-link-icon
			c: #dc2626

		.verse-number-text
			vertical-align: middle
			d: inline

		note-tooltip svg
			c:$acc @hover:$acc-hover
			size:0.68em

		.reload
			display: block
			mt:.5rem
			w: 100%
			cursor: pointer
			text-decoration: solid underline
			y@hover:-2px

		.selected-verse
			c@important: $acc
			background: none
			background-image: none
			background-color: transparent
		
		span.selected-verse::selection,
		span.selected-verse::-moz-selection
			background-color: transparent
			color: $acc

		# Verse selection overlay box (matches Obsidian plugin style)
		.verse-selection-box
			position: absolute
			left: 0
			right: 0
			border-radius: 8px
			background: color-mix(in srgb, #a855f7 15%, transparent)
			border: 2px solid #a855f7
			z-index: 0
			pointer-events: none
			transition: top 150ms ease, height 150ms ease
			display: none
			padding-left: 20px
			padding-right: 20px

		.verse-selection-box[style*="display: block"]
			display: block

		# Insert button inside selection box
		.verse-selection-insert-btn
			position: absolute
			left: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 6px 0 0 6px
			display: flex
			align-items: center
			justify-content: center
			cursor: pointer
			pointer-events: auto
			transition: all 0.15s ease
			background@hover: #9333ea
			opacity@hover: 0.8
			background@active: #9333ea
			opacity@active: 0.7
			box-sizing: border-box
			padding: 0
			margin: 0
			overflow: hidden

		.verse-selection-insert-btn svg
			width: 14px
			height: 14px
			color: white
			display: block
			flex-shrink: 0
			margin: 0 auto
			position: relative

		# Close button inside selection box (on the right)
		.verse-selection-close-btn
			position: absolute
			right: 0
			top: 0
			bottom: 0
			width: 20px
			min-width: 20px
			max-width: 20px
			background: #a855f7
			border: none
			border-radius: 0 6px 6px 0
			display: flex
			align-items: center
			justify-content: center
			cursor: pointer
			pointer-events: auto
			transition: all 0.15s ease
			background@hover: #9333ea
			opacity@hover: 0.8
			background@active: #9333ea
			opacity@active: 0.7
			box-sizing: border-box
			padding: 0
			margin: 0
			overflow: hidden

		.verse-selection-close-btn svg
			width: 14px
			height: 14px
			color: white
			display: block
			flex-shrink: 0
			margin: 0
			padding: 0
			position: relative

		# Drag handles
		.verse-selection-handle
			position: absolute
			left: 50%
			transform: translateX(-50%)
			width: 64px
			height: 6px
			border-radius: 999px
			background: #a855f7
			cursor: ns-resize
			pointer-events: auto
			z-index: 6
			# ensure it stays visually centered on the box border
			margin-left: 0

		.verse-selection-handle-top
			top: -4px

		.verse-selection-handle-bottom
			bottom: -4px

		html[data-copy-select-dragging="true"] .verse-selection-box
			transition: none

		.in-offline
			padding: 2rem
			text-align: center

		.chapter-drawing-surface
			position: absolute
			top: 0
			left: 0
			right: 0
			bottom: 0
			overflow: hidden
			pointer-events: none
			z-index: auto

		.freehand-stroke-canvas
			position: absolute
			top: 0
			left: 0
			width: 100%
			height: 100%
			max-width: 100%
			pointer-events: none
			z-index: 2
			opacity: 0.72
			mix-blend-mode: multiply
			transition: none

		html.freehand-mode &
			touch-action: none
			-webkit-touch-callout: none

		html.pen-mode &
			touch-action: none
			-webkit-touch-callout: none

		html.stylus-drawing &
			touch-action: none
			-webkit-touch-callout: none
			user-select: none
			-webkit-user-select: none

		.pen-sketch-layer
			position: absolute
			top: 0
			left: 0
			width: 100%
			height: 100%
			max-width: 100%
			pointer-events: none
			z-index: 1
			overflow: hidden