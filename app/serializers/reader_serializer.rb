# Hand-written for the same reason BookSerializer is: the payload is small and fixed.
class ReaderSerializer
  def initialize(reader)
    @reader = reader
  end

  def as_json
    {
      card_number: reader.card_number,
      full_name: reader.full_name,
      email: reader.email
    }
  end

  private

  attr_reader :reader
end
