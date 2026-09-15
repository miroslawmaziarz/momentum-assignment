class BookSerializer
  def initialize(book, history: false)
    @book = book
    @history = history
  end

  def as_json
    payload = {
      serial_number: book.serial_number,
      title: book.title,
      author: book.author,
      status: book.status
    }
    payload[:history] = history_entries if history
    payload
  end

  private

  attr_reader :book, :history

  def history_entries
    book.history.map { |borrowing| BorrowingSerializer.new(borrowing).as_json }
  end
end
