import activities from '../lib/Activities'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import { hasTouchEvents } from '../constants'
import { setValue } from '../utils'
import X from 'lucide-static/icons/x.svg'
import PatternFill from '../icons/pattern-fill.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import ChevronUp from 'lucide-static/icons/chevron-up.svg'
import Trash2 from 'lucide-static/icons/trash-2.svg'
import Eraser from 'lucide-static/icons/eraser.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import Pen from 'lucide-static/icons/pen.svg'
import Undo2 from 'lucide-static/icons/undo-2.svg'

const DEFAULT_Y = 32

tag freehand-highlight-menu
	#dy = DEFAULT_Y

	def setHighlightColor event
		if event.detail
			activities.freehandHighlightColor = event.detail

	get commentaryToolTarget
		return activities.activeVerseAction == 'commentary' or activities.commentaryCompareMode

	def clearAllHighlights e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if commentaryToolTarget
			if hasTouchEvents or window.confirm("Clear all highlights in this commentary?")
				window.dispatchEvent(new CustomEvent('commentary-freehand-clear'))
			return
		if activities.penToolMode
			console.log('[PEN DEBUG] clear all sketches', { chapter: "{reader.translation}:{reader.book}:{reader.chapter}" })
			reader.clearPenSketchesForCurrentChapter!
			if parallelReader.enabled
				parallelReader.clearPenSketchesForCurrentChapter!
		elif hasTouchEvents or window.confirm("Clear all highlights in this chapter?")
			reader.clearAllChapterHighlights!
			if parallelReader.enabled
				parallelReader.clearAllChapterHighlights!

	def close
		console.log('[PEN DEBUG] close tool menu')
		reader.refreshFreehandHighlightDisplay!
		if parallelReader.enabled
			parallelReader.refreshFreehandHighlightDisplay!
		activities.freehandHighlightMode = no
		activities.penToolMode = no
		activities.isFreehandHighlightMinimized = no
		activities.freehandEraserMode = no
		activities.penEraserMode = no
		activities.clearBottomToolbarLift!
		imba.commit!

	def setPenThickness e
		let raw = e and e.target ? e.target.value : null
		let n = Number(raw)
		if !Number.isFinite(n)
			return
		activities.penLineWidth = Math.max(1, Math.min(24, n))
		setValue('pen-line-width', activities.penLineWidth)

	get canUndoFreehand
		if activities.penToolMode
			return no
		if commentaryToolTarget
			return activities.commentaryFreehandCount > 0
		if reader.freehandHighlights and reader.freehandHighlights.length > 0
			return yes
		if parallelReader.enabled and parallelReader.freehandHighlights and parallelReader.freehandHighlights.length > 0
			return yes
		return no

	def undoReaders
		let list = [reader]
		if parallelReader.enabled
			list.push(parallelReader)
		return list

	def undoLastFreehandHighlight e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
		if activities.penToolMode or !canUndoFreehand
			return
		if commentaryToolTarget
			window.dispatchEvent(new CustomEvent('commentary-freehand-undo'))
			return
		let target = null
		for r in undoReaders!
			if !r.freehandHighlights or r.freehandHighlights.length == 0
				continue
			let last = r.freehandHighlights[r.freehandHighlights.length - 1]
			let ts = last.date or 0
			if !target or ts >= target.ts
				target = { reader: r, ts: ts }
		if !target
			return
		target.reader.freehandHighlights = target.reader.freehandHighlights.slice(0, -1)
		target.reader.saveFreehandHighlights!
		imba.commit!

	get transitionDuration
		return #dy == DEFAULT_Y ? '0.5s' : '0s'

	<self [y:{(activities.freehandHighlightMode or activities.penToolMode) ? (activities.isFreehandHighlightMinimized ? (window.innerWidth < 1024 ? 'calc(100% - 2.75rem)' : '100%') : #dy + 'px') : '100%'} @off:100% o@off:0 transition-duration:{transitionDuration}] ease
		[zi:1400]=(activities.activeVerseAction == 'commentary' or activities.commentaryCompareMode)
		.is-minimized=activities.isFreehandHighlightMinimized
		@click.stop @pointerdown.stop @pointerup.stop>
		<div.control-tabs>
			<button.tab.minimize @click=(do
				activities.isFreehandHighlightMinimized = !activities.isFreehandHighlightMinimized
				if activities.isFreehandHighlightMinimized
					activities.clearBottomToolbarLift!
				else
					activities.armBottomToolbarLift!
					activities.playContentLift!
			) title=(activities.isFreehandHighlightMinimized ? "Restore" : "Minimize")>
				<svg src=(activities.isFreehandHighlightMinimized ? ChevronUp : ChevronDown)>
			<button.tab.close @click=close title="Close">
				<svg src=X>
		<svg.chevron src=ChevronDown @click=close>
		unless activities.penToolMode
			<ul.underline-options>
				for style in activities.underlineStyles
					<li.underline-option
						role="button"
						aria-label=style.label
						title=style.label
						.disabled=!activities.patternHighlightMode
						.selected=(activities.patternHighlightMode and activities.underlineStyle == style.id)
						@click.stop.prevent=(if activities.patternHighlightMode then activities.setUnderlineStyle(style.id))>
						<span.preview data-style=style.id>

		<ul.color-options>
			unless activities.penToolMode
				<li.color-option.pattern-option
					role="button"
					aria-label="Underline pattern" title="Underline pattern"
					.selected=activities.patternHighlightMode
					@click.stop.prevent=activities.togglePatternHighlightMode>
					<svg src=PatternFill aria-hidden=yes>

			<li.color-option[scale:unset]>
				<color-picker[w:100%] color=activities.freehandHighlightColor @change=setHighlightColor>

			for color in (activities.penToolMode ? activities.penColors : activities.highlightColors)
				<li.color-option [background:{color}] title=color role="button" aria-label=color
					.selected=(activities.freehandHighlightColor == color)
					@click.stop.prevent=(do
						activities.freehandHighlightColor = color
						activities.freehandEraserMode = no
						activities.penEraserMode = no
					)>

		if activities.penToolMode
			<div.thickness-row>
				<span> "Thickness"
				<input type='range' min='1' max='24' step='1' value=activities.penLineWidth @input=setPenThickness>
				<span.thickness-value> activities.penLineWidth

		<menu>
			if activities.penToolMode
				<li>
					<button .active=!activities.penEraserMode
						@click=(activities.penEraserMode = no)
						role="button" aria-label="Draw" title="Draw Tool">
						<svg src=Pen width="1.5rem" height="1.5rem">
				<li>
					<button .active=activities.penEraserMode
						@click=(activities.penEraserMode = yes)
						role="button" aria-label="Erase" title="Erase Tool">
						<svg src=Eraser width="1.5rem" height="1.5rem">
			else
				<li>
					<button @click.stop.prevent=undoLastFreehandHighlight disabled=!canUndoFreehand role="button" aria-label="Undo" title="Undo">
						<svg src=Undo2 width="1.5rem" height="1.5rem">
				<li>
					<button .active=!activities.freehandEraserMode 
						@click=(activities.freehandEraserMode = no) 
						role="button" aria-label="Highlight" title="Highlight Tool">
						<svg src=Highlighter width="1.5rem" height="1.5rem">
				<li>
					<button .active=activities.freehandEraserMode 
						@click=(activities.freehandEraserMode = yes) 
						role="button" aria-label="Eraser" title="Eraser Tool">
						<svg src=Eraser width="1.5rem" height="1.5rem">
			<li>
				<button @click.stop.prevent=clearAllHighlights role="button" aria-label="Clear all" title="Clear all highlights">
					<svg src=Trash2 width="1.5rem" height="1.5rem">

	css
		pos:fixed b:0 l:0 r:0 zi:1100
		w:100% bgc:$bgc
		bdt:1px solid $acc-bgc
		ta:center
		d:vcc
		cursor: default
		padding-block:1rem 2.5rem
		transition-property: transform, opacity

		&.is-minimized
			bgc: transparent
			bdt: none
			pointer-events: none
			.control-tabs
				pointer-events: auto
			header, .underline-options, ul, menu
				o: 0

		.chevron
			pos:absolute
			top:-0.25rem
			scale-x: 2
			scale-y: 0.5
			cursor: pointer
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

		header
			d:hcs
			g:0.5rem

		.underline-options
			d: flex
			flw: nowrap
			jc: center
			ai: center
			g: 0.6rem
			pb: 0.5rem
			max-width: 100%
			padding-inline: 0.5rem

		.underline-option
			list-style: none
			size: 3.25rem 1.9rem
			d: hcc
			cursor: pointer
			fls: 0
			c: $acc @hover:$acc-hover
			rd: 0.35rem
			p: 0 0.35rem
			scale@hover: 1.15

			&.disabled
				opacity: 0.28
				cursor: pointer
				c: $c
				scale@hover: 1

			&.selected
				bgc: $acc-bgc-hover

			.preview
				d: block
				w: 100%
				h: 0
				border-bottom: 4px solid currentColor

				&[data-style="dotted"]
					border-bottom-style: dotted

				&[data-style="dashed"]
					border-bottom-style: dashed

				&[data-style="double"]
					border-bottom-width: 6px
					border-bottom-style: double

				# A real sine wave, masked so it still follows currentColor.
				&[data-style="wavy"]
					border-bottom: none
					h: 8px
					background-color: currentColor
					-webkit-mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 8'%3E%3Cpath d='M0 5.5 Q 3 1.5 6 5.5 T 12 5.5' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round'/%3E%3C/svg%3E")
					mask-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 8'%3E%3Cpath d='M0 5.5 Q 3 1.5 6 5.5 T 12 5.5' fill='none' stroke='%23000' stroke-width='2.2' stroke-linecap='round'/%3E%3C/svg%3E")
					-webkit-mask-repeat: repeat-x
					mask-repeat: repeat-x
					-webkit-mask-size: 12px 8px
					mask-size: 12px 8px
					-webkit-mask-position: bottom
					mask-position: bottom

		.color-options
			white-space: nowrap
			padding-block: 0rem .5rem
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
			&.selected:not(.pattern-option)
				border: 3px solid $acc

			&.pattern-option
				bgc: transparent
				bd: none
				p: 0
				overflow: hidden
				d: block
				c: $acc @hover:$acc-hover

				&.selected
					bgc: $acc-bgc-hover
					c: $acc-hover

				svg
					d: block
					size: 2rem
					c: inherit

		menu
			d:hcc
			pos:relative
			flw:wrap

		button[disabled]
			opacity: 0.35
			cursor: not-allowed

		button
			display:hcc g:.25rem
			c:$c @hover:$acc
			bgc:transparent @hover:$acc-bgc-hover
			padding:0.75rem
			cursor:pointer
			rd:0.25rem
			transition: all 0.2s
			&.active
				c: $acc

		li
			list-style-type: none
			d:inline-block

		.thickness-row
			d:flex
			ai:center
			jc:center
			g:0.5rem
			pb:0.5rem

		.thickness-value
			min-width:2ch
			ta:right

