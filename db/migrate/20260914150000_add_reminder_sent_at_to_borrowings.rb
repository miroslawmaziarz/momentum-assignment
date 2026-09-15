class AddReminderSentAtToBorrowings < ActiveRecord::Migration[8.1]
  def change
    add_column :borrowings, :due_soon_reminder_sent_at, :datetime
    add_column :borrowings, :due_today_reminder_sent_at, :datetime
  end
end
