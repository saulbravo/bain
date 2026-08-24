import API from './Api'
import { getValue, setValue } from '../utils'

const DEFAULT_ID = 'cba'
const EGW_ID = 'elena-g-white-new'
const DEFAULT_NAME = 'Comentario Bíblico Adventista'
# These two always lead the tab strip and can't be turned off.
const PINNED_IDS = [DEFAULT_ID, EGW_ID]

def readHidden
	const stored = getValue('commentary-hidden')
	return Array.isArray(stored) ? stored : []

class Commentaries
	sources = [{ id: DEFAULT_ID, name: DEFAULT_NAME, abbreviation: 'CBA', short: 'CBA' }]
	loaded = no
	loading = no

	@observable current\string = getValue('commentary') or DEFAULT_ID
	# Stored as the hidden ones so modules added later show up by default.
	@observable hidden = readHidden()

	@autorun def saveCurrent
		setValue('commentary', current)

	@autorun def saveHidden
		setValue('commentary-hidden', hidden)

	def isPinned id\string
		return PINNED_IDS.indexOf(id) >= 0

	def isEnabled id\string
		return yes if isPinned(id)
		return hidden.indexOf(id) < 0

	get visibleSources
		return sources.filter do |source| isEnabled(source.id)

	def toggle id\string
		return if isPinned(id)
		hidden = isEnabled(id) ? hidden.concat([id]) : hidden.filter(do |item| item != id)
		unless isEnabled(current)
			const fallback = visibleSources[0]
			current = fallback ? fallback.id : DEFAULT_ID

	# Keeps CBA and EGW as the first two tabs, in that order.
	def orderSources list
		const pinned = []
		for id in PINNED_IDS
			for source in list when source.id == id
				pinned.push(source)
		return pinned.concat(list.filter(do |source| !isPinned(source.id)))

	get currentSource
		for source in sources
			if source.id == current
				return source
		return sources[0]

	get currentName
		const source = currentSource
		return source and source.name ? source.name : DEFAULT_NAME

	def shortNameFor source
		return '' unless source
		return source.short or source.abbreviation or source.name

	def select id\string
		return if !id or id == current
		current = id

	def load
		return if loaded or loading
		loading = yes
		try
			const list = await API.getJson('/get-commentaries/')
			if Array.isArray(list) and list.length
				sources = orderSources(list)
				# A module can be removed from the server between visits.
				const ids = sources.map(do |source| return source.id)
				hidden = hidden.filter(do |id| ids.indexOf(id) >= 0)
				unless ids.indexOf(current) >= 0 and isEnabled(current)
					const fallback = visibleSources[0] or sources[0]
					current = fallback.id
			loaded = yes
		catch error
			console.log "Error fetching commentaries:", error
		finally
			loading = no
			imba.commit!

const commentaries = new Commentaries
export default commentaries
