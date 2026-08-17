import activities from '../lib/Activities'
import API from '../lib/Api'
import reader from '../lib/Reader'
import parallelReader from '../lib/ParallelReader'
import X from 'lucide-static/icons/x.svg'
import ChevronLeft from 'lucide-static/icons/chevron-left.svg'
import ChevronRight from 'lucide-static/icons/chevron-right.svg'

tag verse-commentary-modal
	loading = no
	error = ''
	commentaryHtml = ''
	currentVerse = 0
	lastLoadKey = ''

	get currentReader
		if activities.selectedParallel == 'main'
			return reader
		if activities.selectedParallel and activities.selectedParallel != 'main'
			return parallelReader
		return reader

	def getVerseNumbers
		let nums = (currentReader.verses or []).map(do |v| return v.verse)
		nums.sort(do |a, b| return a - b)
		return nums

	def clampCurrentVerse
		let nums = getVerseNumbers!
		if nums.length == 0
			currentVerse = 0
			return
		if currentVerse <= 0
			if activities.selectedVerses and activities.selectedVerses.length
				# Open commentary on the most recently selected verse (the one user tapped last).
				currentVerse = activities.selectedVerses[activities.selectedVerses.length - 1]
			else
				currentVerse = nums[0]
		if !nums.includes(currentVerse)
			# Choose nearest valid verse if current one is missing.
			let nearest = nums[0]
			let nearestDistance = Math.abs(nums[0] - currentVerse)
			for n in nums
				let d = Math.abs(n - currentVerse)
				if d < nearestDistance
					nearestDistance = d
					nearest = n
			currentVerse = nearest

	def close
		# Return to options slideup while keeping current selection.
		activities.activeVerseAction = 'options'
		imba.commit!

	def stepVerse delta\number
		let nums = getVerseNumbers!
		return if nums.length == 0
		let idx = nums.indexOf(currentVerse)
		if idx < 0
			idx = 0
		let next = Math.max(0, Math.min(nums.length - 1, idx + delta))
		currentVerse = nums[next]
		imba.commit!
		loadCommentary!

	get canGoPrev
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(currentVerse)
		return idx > 0

	get canGoNext
		let nums = getVerseNumbers!
		if nums.length == 0
			return no
		let idx = nums.indexOf(currentVerse)
		return idx >= 0 and idx < nums.length - 1

	def loadCommentary
		clampCurrentVerse!
		return if currentVerse <= 0
		let key = "{currentReader.book}:{currentReader.chapter}:{currentVerse}"
		return if key == lastLoadKey
		lastLoadKey = key
		loading = yes
		error = ''
		commentaryHtml = ''
		imba.commit!
		try
			let payload = await API.getJson("/get-cba-commentary/{currentReader.book}/{currentReader.chapter}/{currentVerse}/")
			commentaryHtml = payload and payload.commentaryHtml ? payload.commentaryHtml : ''
		catch err
			error = err and err.message ? err.message : 'Unable to load commentary'
		finally
			loading = no
			imba.commit!

	@autorun def syncAndReload
		const action = activities.activeVerseAction
		const selected = activities.selectedVerses and activities.selectedVerses.slice().sort(do |a, b| return a - b).join(',')
		const translation = currentReader.translation
		const book = currentReader.book
		const chapter = currentReader.chapter
		if action == 'commentary'
			clampCurrentVerse!
			loadCommentary!

	<self>
		<div.commentary-overlay @click=close>
		<section.commentary-modal @click.stop>
			<header>
				<div.title-wrap>
					<h3> "Comentario Bíblico Adventista"
					<p.verse-ref> "{currentReader.nameOfCurrentBook} {currentReader.chapter}:{currentVerse}"
				<button.close-btn @click=close title="Close">
					<svg src=X>
			<div.nav-row>
				<button.nav-btn @click=stepVerse(-1) disabled=!canGoPrev title="Previous verse">
					<svg src=ChevronLeft>
				<button.nav-btn @click=stepVerse(1) disabled=!canGoNext title="Next verse">
					<svg src=ChevronRight>
			<div.content>
				if loading
					<p> "Loading commentary..."
				elif error
					<p.error> error
				elif commentaryHtml and commentaryHtml.length
					<div.commentary-text innerHTML=commentaryHtml>
				else
					<p> "No commentary available for this verse."

	css
		pos: fixed
		inset: 0
		zi: 1300
		d: flex
		ai: center
		jc: center
		padding: 1rem

		.commentary-overlay
			pos: absolute
			inset: 0
			bgc: rgba(15, 23, 42, 0.35)

		.commentary-modal
			pos: relative
			zi: 1
			width: min(56rem, 100%)
			max-height: min(75vh, 42rem)
			bgc: $bgc
			color: $c
			rd: 0.75rem
			bxs: 0 10px 30px rgba(0, 0, 0, 0.25)
			d: flex
			fld: column
			overflow: hidden

		header
			d: flex
			ai: flex-start
			jc: space-between
			g: 1rem
			padding: 1rem 1rem 0.75rem
			bdb: 1px solid $acc-bgc

		.title-wrap
			d: flex
			fld: column

		h3
			m: 0
			fs: 1.05rem
			fw: 700

		.verse-ref
			m: 0.25rem 0 0
			c: $acc
			fs: 0.9rem

		.close-btn
			bgc: transparent
			c: $c
			p: 0.25rem
			rd: 0.375rem
			cursor: pointer
			svg
				size: 1.2rem

		.nav-row
			d: flex
			jc: space-between
			padding: 0.5rem 1rem
			bdb: 1px solid $acc-bgc

		.nav-btn
			bgc: $acc-bgc
			c: $c
			p: 0.35rem 0.6rem
			rd: 0.4rem
			cursor: pointer
			d: hcc
			&:disabled
				opacity: 0.4
				cursor: not-allowed
			svg
				size: 1.1rem

		.content
			overflow: auto
			padding: 1rem
			lh: 1.55
			-webkit-overflow-scrolling: touch

		.commentary-text
			white-space: normal
			word-break: break-word

		.error
			c: #ef4444
