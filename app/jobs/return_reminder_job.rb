class ReturnReminderJob < ApplicationJob
  queue_as :default

  DUE_SOON_DAYS = 3
  DUE_TODAY_DAYS = 0

  REMINDERS = [
    {
      days_before_due: DUE_SOON_DAYS,
      mailer_method: :due_soon,
      sent_at_column: :due_soon_reminder_sent_at
    },
    {
      days_before_due: DUE_TODAY_DAYS,
      mailer_method: :due_today,
      sent_at_column: :due_today_reminder_sent_at
    }
  ].freeze

  def perform
    REMINDERS.each do |reminder|
      send_reminders(**reminder)
    end
  end

  private

  def send_reminders(days_before_due:, mailer_method:, sent_at_column:)
    target_date = days_before_due.days.from_now.to_date

    Borrowing.open.due_on(target_date).where(sent_at_column => nil)
             .includes(:book, :reader).find_each do |borrowing|
      borrowing.update!(sent_at_column => Time.current)
      ReminderMailer.public_send(mailer_method, borrowing).deliver_now
    end
  end
end
