import activities from '../lib/Activities'
import Plus from 'lucide-static/icons/plus.svg'
import X from 'lucide-static/icons/x.svg'

tag bible-tabs
	prop scale = 1

	<self>
		<div.tabs-container [padding-inline:{scale}rem]>
			for tab, index in activities.tabs
				<div.tab .active=(activities.activeTabIndex == index) @click=activities.switchTab(index) [padding:{scale * 0.5}rem {scale * 1}rem max-width:{scale * 12}rem]>
					<span.tab-name [fs:{scale * 0.875}rem]> tab.name
					if activities.tabs.length > 1
						<div.close-tab @click.stop=activities.closeTab(index) [size:{scale * 1.25}rem]>
							<svg src=X [size:{scale * 0.75}rem]>
			
			<button.add-tab @click=activities.addTab title="Add new tab" [size:{scale * 2}rem]>
				<svg src=Plus [size:{scale * 1.25}rem]>

	css
		d: block
		w: 100%
		bgc: transparent
		overflow-x: auto
		overflow-y: visible
		scrollbar-width: none
		&::-webkit-scrollbar
			d: none

		.tabs-container
			d: flex
			ai: flex-end
			gap: 4px
			pos: relative
			w: 100%
			min-width: 0
			box-sizing: border-box
			overflow: visible

			&::after
				content: ''
				pos: absolute
				left: 0
				right: 0
				bottom: 0
				h: 1px
				bgc: $acc-bgc
				zi: 0
				pointer-events: none

		.tab
			pos: relative
			d: flex
			ai: center
			gap: 8px
			bgc: $acc-bgc
			rd: 0.5rem 0.5rem 0 0
			cursor: pointer
			white-space: nowrap
			transition: all 0.2s
			jc: space-between
			border: 1px solid transparent
			border-bottom: none
			zi: 1
			flex: 1 1 0
			min-width: 0
			overflow: visible

			&.active
				bgc: $bgc
				bd: 1px solid $acc-bgc
				border-bottom: none
				zi: 3

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

				.tab-name
					fw: bold
					c: $acc

			@hover
				bgc: $acc-bgc-hover

		.tab-name
			user-select: none
			flex: 1 1 auto
			min-width: 0
			overflow: hidden
			text-overflow: ellipsis

		.close-tab
			d: hcc
			rd: 50%
			o: 0.5
			@hover
				o: 1
				bgc: $acc-bgc-hover

		.add-tab
			d: hcc
			bgc: transparent
			c: $acc
			cursor: pointer
			rd: 50%
			flex: 0 0 auto
			@hover
				bgc: $acc-bgc
			mb: 4px

