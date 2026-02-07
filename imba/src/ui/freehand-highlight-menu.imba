import activities from '../lib/Activities'
import SlidersHorizontal from 'lucide-static/icons/sliders-horizontal.svg'
import X from 'lucide-static/icons/x.svg'
import Dices from 'lucide-static/icons/dices.svg'
import ChevronDown from 'lucide-static/icons/chevron-down.svg'

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
					@click.stop.prevent=(activities.freehandHighlightColor = color)>

	css
		pos:fixed b:0 l:0 r:0 zi:1100
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
			d:hcs
			g:0.5rem
			span
				tt:uppercase fw:700
				fs:0.875rem
				o:0.7

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

