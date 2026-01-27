tag notifications
	<self>
		for notification in notifications.notifications
			<p.{notification.className} @click=notifications.hide(notification)> notification.message

	css
		position: fixed
		t:0 l:0
		height:0
		zi:1600
		cursor:pointer

	css p
		color: $bgc
		bgc: $acc-hover
		animation: show-notification 500ms cubic-bezier(1, 0, 0, 1) both
		p: 0.5rem 1rem
		border-radius: 0.5rem
		position:absolute
		top: 0.75rem
		left: 0.75rem
		font-size: 0.875rem

	css .hide-notification
		animation-name: hide-notification



	css @keyframes
		show-notification
			0%
				top: -2rem
				left: 0.75rem
				transform: scale(0.8)
				opacity: 0

			100%
				top: 0.75rem
				left: 0.75rem
				transform: none
				opacity: 1

		hide-notification
			0%
				top: 0.75rem
				left: 0.75rem
				transform: none
				opacity: 1

			100%
				top: -2rem
				left: 0.75rem
				transform: scale(0.8)
				opacity: 0
				visibility: hidden
