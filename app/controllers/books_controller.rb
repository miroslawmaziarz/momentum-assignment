class BooksController < ApplicationController
  STATUSES = %w[borrowed available].freeze

  def index
    books = Book.in_catalogue_order.with_status
    render json: books.map { |book| BookSerializer.new(book) }
  end

  def show
    render json: BookSerializer.new(Book.find_by_serial_number!(params[:serial_number]), history: true)
  end

  def create
    book = Book.new(book_params)
    book.save!

    render json: BookSerializer.new(book), status: :created
  rescue ActiveRecord::RecordNotUnique
    book.validate
    book.errors.add(:base, :taken) if book.errors.empty?

    raise ActiveRecord::RecordInvalid, book
  end

  def update
    book = Book.find_by_serial_number!(params[:serial_number])

    case params[:status]
    when "borrowed"
      borrowing = Borrowings::LendBook.call(book:, card_number: params.require(:card_number))
      render json: BorrowingSerializer.new(borrowing), status: :created
    when "available"
      borrowing = Borrowings::ReturnBook.call(book:)
      render json: BorrowingSerializer.new(borrowing)
    else
      reject_unrecognised_status
    end
  end

  def destroy
    # TODO soft-delete
    book = Book.find_by_serial_number!(params[:serial_number])

    book.with_lock do
      refuse_deletion(book) if book.borrowed?
      book.destroy!
    end

    head :no_content
  end

  private

  def book_params
    params.require(:book).permit(:serial_number, :title, :author)
  end

  # A broken rule about what a request is allowed to do, rather than a failed validation of the
  # values it sent, still answers as a rejected write: the same envelope, the same 422. Nothing
  # suitable exists to blame for an unrecognised status, so an unsaved book is built just to
  # carry the message.
  def reject_unrecognised_status
    book = Book.new
    book.errors.add(:status, "must be one of: #{STATUSES.join(', ')}")

    raise ActiveRecord::RecordInvalid, book
  end

  # Here the book refused for deletion is itself the thing the rule was about, so it carries
  # the error.
  def refuse_deletion(book)
    book.errors.add(:base, "This book is currently borrowed and cannot be deleted.")

    raise ActiveRecord::RecordInvalid, book
  end
end
