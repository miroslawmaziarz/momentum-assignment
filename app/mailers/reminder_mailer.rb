class ReminderMailer < ApplicationMailer
  def due_soon(borrowing)
    @borrowing = borrowing
    mail(
      to: borrowing.reader.email,
      subject: "#{borrowing.book.title} is due back in #{ReturnReminderJob::DUE_SOON_DAYS} days"
    )
  end

  def due_today(borrowing)
    @borrowing = borrowing
    mail(
      to: borrowing.reader.email,
      subject: "#{borrowing.book.title} is due back today"
    )
  end
end
