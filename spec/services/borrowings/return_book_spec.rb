require "rails_helper"

RSpec.describe Borrowings::ReturnBook do
  it "closes the open borrowing" do
    book = create(:book, serial_number: "123456")
    borrowing = create(:borrowing, book:)

    returned = described_class.call(book: book.reload)

    expect(returned).to eq(borrowing)
    expect(returned.returned_at).to be_present
  end

  it "refuses to return a book that is not currently out" do
    book = create(:book, serial_number: "123456")

    expect { described_class.call(book:) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "refuses a second return of the same loan" do
    book = create(:book, serial_number: "123456")
    create(:borrowing, book:)
    described_class.call(book: book.reload)

    expect { described_class.call(book: book.reload) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
