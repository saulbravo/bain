import { setValue, getValue, deleteValue, scoreSearch } from '../utils'

import activities from './Activities'
import reader from './Reader'
import parallelReader from './ParallelReader'

import ALL_BOOKS from '../data/translations_books.json'

class GoToBook
	@observable query\string = ''
	suggestions = {}
	recentSearches\string[] = getValue('gotobook_recent_searches') || []
	maxRecentSearches = 10

	@autorun
	def saveRecentSearches
		if recentSearches.length
			setValue('gotobook_recent_searches', recentSearches)
		else
			deleteValue('gotobook_recent_searches')

	get inputElement
		return document.getElementById('gotobooksearch')

	@computed get activeTranslation
		if activities.activeParallelAtBooksDrawer && parallelReader.enabled
			return parallelReader.translation
		return reader.translation || 'YLT'

	@computed get books
		unless ALL_BOOKS[activeTranslation]
			return ALL_BOOKS['YLT']
		return ALL_BOOKS[activeTranslation].sort(do(a, b) return a.bookid - b.bookid)

	@autorun
	def generateSuggestions
		console.log('[DEBUG] GoToBook.generateSuggestions called:', { query, queryLength: query.length })
		const trimmedQuery = query.trim!.toLowerCase!
		unless trimmedQuery.length
			suggestions = {}
			return

		const parts = trimmedQuery.split(' ')
		let numbers_part = ''
		let numbers_index = -1
		
		# Find the first part that contains numbers
		for part, index in parts
			if /\d/.test(part)
				numbers_part = part
				numbers_index = index
				break

		suggestions.chapter = null
		suggestions.verse = null

		# Parse chapter and verse from numbers_part
		if numbers_part
			# If verse is included (e.g., "1:1" or "1:5")
			if numbers_part.indexOf(':') > -1
				const ch_v_numbers = numbers_part.split(':')
				suggestions.chapter = parseInt(ch_v_numbers[0])
				if ch_v_numbers[1] && ch_v_numbers[1].length
					suggestions.verse = parseInt(ch_v_numbers[1])
			else
				# Just chapter number
				suggestions.chapter = parseInt(numbers_part)

		# If no numbers provided -- suggest first chapter
		unless suggestions.chapter
			suggestions.chapter = 1

		# Extract book name (everything except the numbers part)
		let bookname_parts = []
		for part, index in parts
			if index != numbers_index
				bookname_parts.push(part)
		const bookname = bookname_parts.join(' ')

		console.log('[DEBUG] GoToBook parsed:', { bookname, chapter: suggestions.chapter, verse: suggestions.verse })

		# Filter books by name
		let filtered_books = []
		if bookname.length > 0
			for book in books
				const score = scoreSearch(book.name, bookname)
				if score
					filtered_books.push({
						book: book
						score: score
					})
				# Also check abbreviation
				const abbr = self.getBookAbbreviation(book.bookid).toLowerCase()
				if abbr.includes(bookname) or bookname.includes(abbr)
					# Check if already added
					unless filtered_books.find(do |item| return item.book.bookid == book.bookid)
						filtered_books.push({
							book: book
							score: 50 # Lower score for abbreviation match
						})

			filtered_books = filtered_books.sort(do |a, b| b.score - a.score)

		# Add recent searches that match
		let recent_matches = []
		for recent in recentSearches
			if recent.toLowerCase().includes(trimmedQuery) or trimmedQuery.includes(recent.toLowerCase())
				recent_matches.push(recent)

		# Generate suggestions list
		suggestions.books = []
		for item in filtered_books
			if reader.theChapterExistInThisTranslation(item.book.bookid, suggestions.chapter)
				suggestions.books.push(item.book)

		suggestions.recent = recent_matches.slice(0, 5) # Limit to 5 recent matches

		console.log('[DEBUG] GoToBook suggestions:', { 
			booksCount: suggestions.books.length, 
			recentCount: suggestions.recent.length,
			chapter: suggestions.chapter,
			verse: suggestions.verse
		})

	def getBookAbbreviation bookNumber\number
		const abbreviations = {
			1: "GEN", 2: "EX", 3: "LEV", 4: "NUM", 5: "DEU",
			6: "JOS", 7: "JDG", 8: "RTH", 9: "1SA", 10: "2SA",
			11: "1KI", 12: "2KI", 13: "1CH", 14: "2CH", 15: "EZR",
			16: "NEH", 17: "EST", 18: "JOB", 19: "PSA", 20: "PRV",
			21: "ECC", 22: "SOS", 23: "ISA", 24: "JER", 25: "LAM",
			26: "EZE", 27: "DAN", 28: "HOS", 29: "JOE", 30: "AMO",
			31: "OBD", 32: "JON", 33: "MIC", 34: "NAH", 35: "HAB",
			36: "ZEP", 37: "HAG", 38: "ZEC", 39: "MAL",
			40: "MAT", 41: "MRK", 42: "LUK", 43: "JN",
			44: "ACT", 45: "ROM", 46: "1CO", 47: "2CO", 48: "GAL",
			49: "EPH", 50: "PHP", 51: "COL", 52: "1TH", 53: "2TH",
			54: "1TI", 55: "2TI", 56: "TIT", 57: "PHM",
			58: "HEB", 59: "JAM", 60: "1PE", 61: "2PE", 62: "1JN",
			63: "2JN", 64: "3JN", 65: "JUD", 66: "REV"
		}
		return abbreviations[bookNumber] || "???"

	def getSuggestionText book
		let text = book.name
		if suggestions.chapter
			text += ' ' + suggestions.chapter
		if suggestions.verse
			text += ':' + suggestions.verse
		return text

	@action def goToBook book\number|object
		console.log('[DEBUG] GoToBook.goToBook called:', { book, suggestions })
		
		# Handle both book object and bookid number
		let bookid = book
		let bookObj = null
		if typeof book == 'object' and book.bookid
			bookid = book.bookid
			bookObj = book
		else
			bookObj = books.find(do |b| return b.bookid == bookid)
		
		const chapter = suggestions.chapter || 1
		const verse = suggestions.verse || null
		
		# Save to recent searches
		if bookObj
			const searchText = getSuggestionText(bookObj)
			if searchText and !recentSearches.includes(searchText)
				recentSearches.unshift(searchText)
				if recentSearches.length > maxRecentSearches
					recentSearches.pop!
		
		console.log('[DEBUG] GoToBook navigating to:', { bookid, chapter, verse, activeTranslation })
		
		# Navigate to the book/chapter/verse
		if activities.activeParallelAtBooksDrawer && parallelReader.enabled
			parallelReader.book = bookid
			parallelReader.chapter = chapter
			if verse
				parallelReader.verse = verse
		else
			reader.book = bookid
			reader.chapter = chapter
			if verse
				reader.verse = verse
		
		# Close modal
		activities.cleanUp!
		console.log('[DEBUG] GoToBook navigation complete')

	@action def goToRecentSearch recentText\string
		console.log('[DEBUG] GoToBook.goToRecentSearch called:', { recentText })
		
		# Parse the recent search text (format: "Book Name 1" or "Book Name 1:1")
		const parts = recentText.split(' ')
		const lastPart = parts[parts.length - 1]
		
		let chapter = 1
		let verse = null
		
		if lastPart.indexOf(':') > -1
			const ch_v = lastPart.split(':')
			chapter = parseInt(ch_v[0])
			if ch_v[1]
				verse = parseInt(ch_v[1])
		else if /\d/.test(lastPart)
			chapter = parseInt(lastPart)
		
		const bookname = parts.slice(0, -1).join(' ')
		
		# Find the book
		const book = books.find(do |b| return b.name.toLowerCase() == bookname.toLowerCase())
		if book
			# Update suggestions to match the recent search
			suggestions.chapter = chapter
			suggestions.verse = verse
			# Navigate directly
			console.log('[DEBUG] GoToBook.goToRecentSearch navigating to:', { bookid: book.bookid, chapter, verse })
			if activities.activeParallelAtBooksDrawer && parallelReader.enabled
				parallelReader.book = book.bookid
				parallelReader.chapter = chapter
				if verse
					parallelReader.verse = verse
			else
				reader.book = book.bookid
				reader.chapter = chapter
				if verse
					reader.verse = verse
			activities.cleanUp!
		else
			console.error('[DEBUG] GoToBook.goToRecentSearch: Book not found:', bookname)

	@action def run
		console.log('[DEBUG] GoToBook.run called:', { query })
		
		# If we have suggestions, go to the first one
		if suggestions.books and suggestions.books.length > 0
			console.log('[DEBUG] GoToBook.run: Going to first suggestion:', suggestions.books[0])
			goToBook(suggestions.books[0])
		else
			console.log('[DEBUG] GoToBook.run: No suggestions available')


const goToBook = new GoToBook()

export default goToBook

