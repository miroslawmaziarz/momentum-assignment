require "rails_helper"

RSpec.describe Borrowings::LendBook do
  it "lends the book to the reader holding that card" do
    book = create(:book, serial_number: "123456")
    reader = create(:reader, card_number: "654321")

    borrowing = described_class.call(book:, card_number: "654321")

    expect(borrowing).to be_persisted
    expect(borrowing.book).to eq(book)
    expect(borrowing.reader).to eq(reader)
  end

  it "reports a lost race against a concurrent lend as a validation failure" do
    book = create(:book, serial_number: "123456")
    create(:reader, card_number: "654321")
    allow_any_instance_of(Borrowing).to receive(:save!)
      .and_raise(ActiveRecord::RecordNotUnique, "duplicate key value violates unique constraint")

    expect { described_class.call(book:, card_number: "654321") }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it "reports a book deleted out from under a concurrent lend as not found" do
    book = create(:book, serial_number: "123456")
    create(:reader, card_number: "654321")
    allow_any_instance_of(Borrowing).to receive(:save!)
      .and_raise(ActiveRecord::InvalidForeignKey, "violates foreign key constraint")

    expect { described_class.call(book:, card_number: "654321") }
      .to raise_error(ActiveRecord::RecordNotFound, /123456/)
  end

  it "raises not found for an unknown card number" do
    book = create(:book, serial_number: "123456")

    expect { described_class.call(book:, card_number: "999999") }
      .to raise_error(ActiveRecord::RecordNotFound)
  end

  it "refuses to lend a book that is already out" do
    book = create(:book, serial_number: "123456")
    create(:borrowing, book:)
    create(:reader, card_number: "654321")

    expect { described_class.call(book:, card_number: "654321") }
      .to raise_error(ActiveRecord::RecordInvalid)
  end
end
