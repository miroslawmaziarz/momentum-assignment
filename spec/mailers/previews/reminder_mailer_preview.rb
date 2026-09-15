class ReminderMailerPreview < ActionMailer::Preview
  def due_soon
    ReminderMailer.due_soon(sample_borrowing(3.days.from_now))
  end

  def due_today
    ReminderMailer.due_today(sample_borrowing(Time.current))
  end

  private

  def sample_borrowing(due_at)
    book = Book.new(title: "The Left Hand of Darkness", author: "Ursula K. Le Guin", serial_number: "000001")
    reader = Reader.new(full_name: "Ada Lovelace", email: "ada@example.com", card_number: "000001")
    Borrowing.new(book:, reader:, borrowed_at: due_at - Borrowing::LOAN_PERIOD, due_at:)
  end
end
