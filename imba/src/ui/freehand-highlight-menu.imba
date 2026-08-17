import activities from '../lib/Activities'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import { hasTouchEvents } from '../constants'
import { setValue } from '../utils'
import X from 'lucide-static/icons/x.svg'
import Dices from 'lucide-static/icons/dices.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import ChevronUp from 'lucide-static/icons/chevron-up.svg'
import Trash2 from 'lucide-static/icons/trash-2.svg'
import Eraser from 'lucide-static/icons/eraser.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'
import Pen from 'lucide-static/icons/pen.svg'

const DEFAULT_Y = 32

tag freehand-highlight-menu
	#dy = DEFAULT_Y

	def setHighlightColor event
		if event.detail
			activities.freehandHighlightColor = event.detail

	def clearAllHighlights e
		if e and e.preventDefault
			e.preventDefault()
		if e and e.stopPropagation
			e.stopPropagation()
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
		imba.commit!

	def setPenThickness e
		let raw = e and e.target ? e.target.value : null
		let n = Number(raw)
		if !Number.isFinite(n)
			return
		activities.penLineWidth = Math.max(1, Math.min(24, n))
		setValue('pen-line-width', activities.penLineWidth)

	get transitionDuration
		return #dy == DEFAULT_Y ? '0.5s' : '0s'

	<self [y:{(activities.freehandHighlightMode or activities.penToolMode) ? (activities.isFreehandHighlightMinimized ? (window.innerWidth < 1024 ? 'calc(100% - 2.75rem)' : '100%') : #dy + 'px') : '100%'} @off:100% o@off:0 transition-duration:{transitionDuration}] ease
		.is-minimized=activities.isFreehandHighlightMinimized>
		<div.control-tabs>
			<button.tab.minimize @click=(activities.isFreehandHighlightMinimized = !activities.isFreehandHighlightMinimized) title=(activities.isFreehandHighlightMinimized ? "Restore" : "Minimize")>
				<svg src=(activities.isFreehandHighlightMinimized ? ChevronUp : ChevronDown)>
			<button.tab.close @click=close title="Close">
				<svg src=X>
		<svg.chevron src=ChevronDown @click=close>
		<header>
			<span> ""

		<ul.color-options>
			<li[d:inline-flex ai:center jc:center cursor:pointer c@hover:$acc m:0 0.25rem]>
				<svg src=Dices width="2rem" height="2rem" role="button" aria-label="Random"
				@click=(activities.freehandHighlightColor = activities.randomColor)>

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
			if !activities.penToolMode
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
		padding-block:1rem 2.5rem
		transition-property: transform, opacity

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

