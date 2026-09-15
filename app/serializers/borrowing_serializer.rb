class BorrowingSerializer
  def initialize(borrowing)
    @borrowing = borrowing
  end

  def as_json
    {
      serial_number: borrowing.serial_number,
      borrowed_at: borrowing.borrowed_at,
      due_at: borrowing.due_at,
      returned_at: borrowing.returned_at,
      reader: ReaderSerializer.new(borrowing.reader).as_json
    }
  end

  private

  attr_reader :borrowing
end
