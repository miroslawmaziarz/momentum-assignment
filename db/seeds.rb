BOOKS = [
  # Available: never borrowed. Exercises the plain "on the shelf" response shape.
  { serial_number: '100001', title: 'The Pragmatic Programmer', author: 'David Thomas & Andrew Hunt' },
  # Currently borrowed, due in three days — one half of the reminder demo.
  { serial_number: '100002', title: 'Clean Code', author: 'Robert C. Martin' },
  # Currently borrowed, due today — the other half of the reminder demo.
  { serial_number: '100003', title: 'The Design of Everyday Things', author: 'Don Norman' },
  # Available again after a completed loan: exercises a history entry with a returned_at.
  { serial_number: '100004', title: 'Domain-Driven Design', author: 'Eric Evans' },
  # Available: a second never-borrowed book, so the catalogue isn't a single example of it.
  { serial_number: '100005', title: 'Refactoring', author: 'Martin Fowler' }
].freeze

READERS = [
  { card_number: '200001', full_name: 'Ada Lovelace', email: 'ada.lovelace@example.com' },
  { card_number: '200002', full_name: 'Grace Hopper', email: 'grace.hopper@example.com' },
  { card_number: '200003', full_name: 'Alan Turing', email: 'alan.turing@example.com' }
].freeze

books = BOOKS.each_with_object({}) do |attrs, memo|
  memo[attrs[:serial_number]] = Book.find_or_create_by!(serial_number: attrs[:serial_number]) do |book|
    book.title = attrs[:title]
    book.author = attrs[:author]
  end
end

readers = READERS.each_with_object({}) do |attrs, memo|
  memo[attrs[:card_number]] = Reader.find_or_create_by!(card_number: attrs[:card_number]) do |reader|
    reader.full_name = attrs[:full_name]
    reader.email = attrs[:email]
  end
end

def seed_borrowing(book, reader, borrowed_at:, returned_at: nil)
  borrowing = Borrowing.find_or_initialize_by(book: book)
  return borrowing if borrowing.persisted?

  borrowing.reader = reader
  borrowing.borrowed_at = borrowed_at
  borrowing.save!
  borrowing.update!(returned_at: returned_at) if returned_at
  borrowing
end

# Due in three days: lent 27 days into the 30-day loan period.
seed_borrowing(books['100002'], readers['200001'], borrowed_at: 27.days.ago)

# Due today: lent the full 30 days ago.
seed_borrowing(books['100003'], readers['200002'], borrowed_at: 30.days.ago)

# A completed loan, already back on the shelf: lent and returned well in the past.
seed_borrowing(books['100004'], readers['200003'], borrowed_at: 60.days.ago, returned_at: 45.days.ago)

puts "Seeded #{Book.count} books, #{Reader.count} readers, #{Borrowing.count} borrowings."
