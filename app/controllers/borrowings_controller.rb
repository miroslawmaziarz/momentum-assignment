class BorrowingsController < ApplicationController
  wrap_parameters :borrowing, include: [ :card_number ]

  def create
    book = Book.find_by_serial_number!(params[:book_serial_number])
    borrowing = Borrowings::LendBook.call(book:, card_number: params.require(:borrowing).require(:card_number))

    render json: BorrowingSerializer.new(borrowing), status: :created
  end
end
