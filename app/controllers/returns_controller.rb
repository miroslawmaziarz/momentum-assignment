class ReturnsController < ApplicationController
  def create
    book = Book.find_by_serial_number!(params[:book_serial_number])
    borrowing = Borrowings::ReturnBook.call(book:)

    render json: BorrowingSerializer.new(borrowing)
  end
end
