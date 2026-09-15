class Book < ApplicationRecord
  include SixDigitBusinessKey

  six_digit_business_key :serial_number

  has_many :borrowings, dependent: nil

  has_one :open_borrowing, -> { open }, class_name: "Borrowing", inverse_of: :book,
                                        dependent: nil

  validates :title, presence: true
  validates :author, presence: true

  scope :in_catalogue_order, -> { order(:serial_number) }
  scope :with_status, -> { includes(:open_borrowing) }

  def borrowed?
    open_borrowing.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  def history
    borrowings.includes(:reader).order(borrowed_at: :desc)
  end
end
