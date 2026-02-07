import activities from '../lib/Activities'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import SlidersHorizontal from 'lucide-static/icons/sliders-horizontal.svg'
import X from 'lucide-static/icons/x.svg'
import Dices from 'lucide-static/icons/dices.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'
import Trash2 from 'lucide-static/icons/trash-2.svg'
import Eraser from 'lucide-static/icons/eraser.svg'
import Highlighter from 'lucide-static/icons/highlighter.svg'

const colors = [
	'FireBrick'
	'Chocolate'
	'GoldenRod'
	'OliveDrab'
	'RoyalBlue'
	'RebeccaPurple'
]

tag freehand-highlight-menu
	def setHighlightColor event
		if event.detail
			activities.freehandHighlightColor = event.detail

	def clearAllHighlights
		if window.confirm("Clear all freehand highlights in this chapter?")
			reader.clearFreehandHighlights!
			if parallelReader.enabled
				parallelReader.clearFreehandHighlights!

	<self [y:0 @off:100% o@off:0 transition-duration:0.3s] ease [y:100%]=!activities.freehandHighlightMode>
		<svg.chevron src=ChevronDown @click=(activities.freehandHighlightMode = no)>
		<header>
			<span> "Freehand Highlight"

		<ul>
			<li[d:inline-flex ai:center jc:center cursor:pointer c@hover:$acc m:0 0.25rem]>
				<svg src=Dices width="2rem" height="2rem" role="button" aria-label="Random"
				@click=(activities.freehandHighlightColor = activities.randomColor)>

			<li.color-option[scale:unset]>
				<color-picker[w:100%] color=activities.freehandHighlightColor @change=setHighlightColor>

			for color in colors
				<li.color-option [background:{color}] title=color role="button" aria-label=color
					@click.stop.prevent=(activities.freehandHighlightColor = color; activities.freehandEraserMode = no)>

		<div.menu-actions>
			<div.action-button .active=!activities.freehandEraserMode 
				@click=(!activities.freehandEraserMode ? (activities.freehandHighlightMode = no) : (activities.freehandEraserMode = no)) 
				role="button" aria-label="Highlight" title="Highlight Tool">
				<svg src=Highlighter width="1.5rem" height="1.5rem">
			<div.action-button .active=activities.freehandEraserMode 
				@click=(activities.freehandEraserMode ? (activities.freehandHighlightMode = no) : (activities.freehandEraserMode = yes)) 
				role="button" aria-label="Eraser" title="Eraser Tool">
				<svg src=Eraser width="1.5rem" height="1.5rem">
			<div.action-button @click=clearAllHighlights role="button" aria-label="Clear all" title="Clear all highlights">
				<svg src=Trash2 width="1.5rem" height="1.5rem">

	css
		pos:fixed b:0 l:0 r:0 zi:1200
		w:100% bgc:$bgc
		bdt:1px solid $acc-bgc
		ta:center
		d:vcc
		padding-block:1rem 2.5rem
		transition-property: transform, opacity

		.chevron
			pos:absolute
			top:-0.25rem
			scale-x: 2
			scale-y: 0.5
			cursor: pointer

		header
			d:hcc
			g:0.5rem
			span
				tt:uppercase fw:700
				fs:0.875rem
				o:0.7

		.menu-actions
			d:hcc
			g:1.5rem
			margin-top: 0.5rem

		.action-button
			d:hcc
			cursor: pointer
			o: 0.5 @hover: 1
			transition: all 0.2s
			&.active
				o: 1
				c: $acc
				transform: scale(1.2)

		ul
			white-space: nowrap
			padding-block: 1rem .5rem
			padding-inline: 0.5rem
			max-width: 100%
			d:hcc
			g:.325rem

		.color-option
			size:2rem
			border-radius: 23%
			cursor: pointer
			border: 1px solid $acc-bgc-hover @hover: 1px solid $bgc
			scale@hover: 1.2

		li
			list-style-type: none
			d:inline-block

