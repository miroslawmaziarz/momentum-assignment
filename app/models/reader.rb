class Reader < ApplicationRecord
  include SixDigitBusinessKey

  six_digit_business_key :card_number

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  scope :in_register_order, -> { order(:card_number) }
end
