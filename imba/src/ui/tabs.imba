import activities from '../lib/Activities'
import { hasTouchEvents } from '../constants'
import Plus from 'lucide-static/icons/plus.svg'
import X from 'lucide-static/icons/x.svg'

tag bible-tabs
	prop scale = 1
	touchInput = hasTouchEvents

	def handleTabClick index
		clearTouchHover!
		if index == activities.activeTabIndex
			activities.toggleBooksMenu!
		else
			activities.switchTab(index)

	def clearTouchHover
		if document.activeElement and document.activeElement.blur
			document.activeElement.blur!
		for el in self.querySelectorAll('.tab, .close-tab, .add-tab')
			el.blur!

	def releaseTouchHover e
		if e.pointerType != 'touch' and e.pointerType != 'pen'
			return
		clearTouchHover!

	<self .touch-input=touchInput>
		<div.tabs-container [padding-inline:{scale}rem]>
			for tab, index in activities.tabs
				<div.tab .active=(activities.activeTabIndex == index) @click=handleTabClick(index) [padding:{scale * 0.5}rem {scale * 1}rem max-width:{scale * 12}rem]>
					<span.tab-name [fs:{scale * 0.875}rem]>
						tab.name
						<sup.tab-translation title=translationFullName(tab.translation)> tab.translation
					if activities.tabs.length > 1
						<div.close-tab @click.stop=(do clearTouchHover!; activities.closeTab(index)) [size:{scale * 1.25}rem]>
							<svg src=X [size:{scale * 0.75}rem]>
			
			<button.add-tab @click=(do clearTouchHover!; activities.addTab!) title="Add new tab" [size:{scale * 2}rem]>
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
			touch-action: manipulation

			@hover
				bgc: $acc-bgc-hover

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
					bgc: $bgc

		.close-tab
			d: hcc
			rd: 50%
			o: 0.5
			touch-action: manipulation
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
			mb: 4px
			touch-action: manipulation
			@hover
				bgc: $acc-bgc

		&.touch-input
			.tab
				@hover
					bgc: $acc-bgc

				&.active
					@hover
						bgc: $bgc

			.close-tab
				@hover
					o: 0.5
					bgc: transparent

			.add-tab
				@hover
					bgc: transparent

		.tab-name
			user-select: none
			flex: 1 1 auto
			min-width: 0
			overflow: hidden
			text-overflow: ellipsis

		.tab-translation
			fs: 0.62em
			vertical-align: super
			line-height: 0
			fw: inherit
			c: inherit
			ml: 0.12em
			letter-spacing: 0.02em
			white-space: nowrap
