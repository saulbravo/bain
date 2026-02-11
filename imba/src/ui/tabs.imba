import activities from '../lib/Activities'
import Plus from 'lucide-static/icons/plus.svg'
import X from 'lucide-static/icons/x.svg'

tag bible-tabs
	prop scale = 1

	<self>
		<div.tabs-container [padding-inline:{scale}rem]>
			for tab, index in activities.tabs
				<div.tab .active=(activities.activeTabIndex == index) @click=activities.switchTab(index) [padding:{scale * 0.5}rem {scale * 1}rem min-width:{scale * 8}rem]>
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
		scrollbar-width: none
		&::-webkit-scrollbar
			d: none

		.tabs-container
			d: flex
			ai: flex-end
			gap: 4px
			border-bottom: 1px solid $acc-bgc
			min-width: fit-content

		.tab
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
			border-bottom: 1px solid transparent
			mb: -1px
			zi: 0

			&.active
				bgc: $bgc
				bd: 1px solid $acc-bgc
				border-bottom-color: $bgc
				zi: 1
				.tab-name
					fw: bold
					c: $acc

			@hover
				bgc: $acc-bgc-hover

		.tab-name
			user-select: none

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
			@hover
				bgc: $acc-bgc
			mb: 4px

