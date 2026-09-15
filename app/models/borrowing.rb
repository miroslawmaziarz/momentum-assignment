class Borrowing < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :book
  belongs_to :reader

  delegate :serial_number, to: :book

  scope :open, -> { where(returned_at: nil) }
  scope :due_on, ->(date) { where(due_at: date.all_day) }

  before_validation :start_loan, on: :create

  validates :borrowed_at, presence: true
  validates :due_at, presence: true
  validate :book_must_be_on_the_shelf, on: :create

  def return!
    update!(returned_at: Time.current)
  end

  def formatted_due_date
    due_at.to_date.strftime("%B %-d, %Y")
  end

  private

  def book_must_be_on_the_shelf
    return if book.blank?

    errors.add(:book, "is already out on loan") if book.borrowed?
  end

  def start_loan
    self.borrowed_at ||= Time.current
    self.due_at = borrowed_at + LOAN_PERIOD
  end
end
