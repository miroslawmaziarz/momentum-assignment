module Borrowings
  class LendBook < ApplicationService
    def initialize(book:, card_number:)
      @book = book
      @card_number = card_number
    end

    def call
      reader = Reader.find_by_card_number!(@card_number)

      borrowing = Borrowing.new(book: @book, reader:)
      borrowing.save!
      borrowing
    rescue ActiveRecord::RecordNotUnique
      borrowing.validate
      borrowing.errors.add(:base, :taken) if borrowing.errors.empty?

      raise ActiveRecord::RecordInvalid, borrowing
    rescue ActiveRecord::InvalidForeignKey
      raise ActiveRecord::RecordNotFound, "No book with serial number #{@book.serial_number}."
    end
  end
end
