module Borrowings
  class ReturnBook < ApplicationService
    def initialize(book:)
      @book = book
    end

    def call
      borrowing = @book.open_borrowing
      refuse_return if borrowing.nil?

      borrowing.return!
      borrowing
    end

    private

    def refuse_return
      borrowing = Borrowing.new(book: @book)
      borrowing.errors.add(:base, "This book is not currently out on loan.")

      raise ActiveRecord::RecordInvalid, borrowing
    end
  end
end
