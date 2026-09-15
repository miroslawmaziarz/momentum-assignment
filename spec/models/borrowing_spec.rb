require "rails_helper"

RSpec.describe Borrowing do
  describe "the partial unique index over open borrowings" do
    it "refuses a second open borrowing for the same book" do
      book = create(:book)
      create(:borrowing, book:)

      expect { insert_borrowing(book:, reader: create(:reader)) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows another borrowing once the previous one is returned" do
      book = create(:book)
      create(:borrowing, :returned, book:)

      expect { insert_borrowing(book:, reader: create(:reader)) }.not_to raise_error
    end

    it "leaves other books alone" do
      create(:borrowing, book: create(:book))

      expect { insert_borrowing(book: create(:book), reader: create(:reader)) }.not_to raise_error
    end
  end

  def insert_borrowing(book:, reader:)
    now = Time.current

    described_class.insert_all!(
      [ { book_id: book.id, reader_id: reader.id, borrowed_at: now,
          due_at: now + described_class::LOAN_PERIOD, created_at: now, updated_at: now } ]
    )
  end
end
