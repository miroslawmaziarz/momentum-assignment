#  Validates the six-digit key, when the key is not provided generates one.
#   class Reader < ApplicationRecord
#     six_digit_business_key :card_number
#   end
module SixDigitBusinessKey
  extend ActiveSupport::Concern

  FORMAT = /\A\d{6}\z/
  SPACE = 1_000_000
  GENERATION_ATTEMPTS = 100

  class_methods do
    def six_digit_business_key(attribute)
      label = attribute.to_s.humanize.downcase

      validates attribute, presence: true, uniqueness: true,
                           format: { with: FORMAT, message: "must be exactly six digits" }

      before_validation on: :create do
        self[attribute] = self.class.public_send(:"unused_#{attribute}") if self[attribute].blank?
      end

      define_singleton_method(:"unused_#{attribute}") do
        GENERATION_ATTEMPTS.times do
          candidate = format("%06d", SecureRandom.random_number(SPACE))
          return candidate unless exists?(attribute => candidate)
        end

        raise "Could not find an unused #{label} in #{GENERATION_ATTEMPTS} attempts."
      end

      define_singleton_method(:"find_by_#{attribute}!") do |value|
        find_by(attribute => value) ||
          raise(ActiveRecord::RecordNotFound,
                "No #{model_name.human.downcase} with #{label} #{value}.")
      end

      define_method(:to_param) { self[attribute] }
    end
  end
end
