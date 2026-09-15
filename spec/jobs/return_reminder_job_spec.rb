require "rails_helper"

RSpec.describe ReturnReminderJob do
  it "sends a reminder for a borrowing due in three days" do
    borrowing = travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }

    travel_to(borrowing.due_at - 3.days) do
      expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ borrowing.reader.email ])
    expect(mail.body.encoded).to include(borrowing.book.title)
    expect(mail.body.encoded).to include(borrowing.formatted_due_date)
  end

  it "sends a reminder for a borrowing due today" do
    borrowing = travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }

    travel_to(borrowing.due_at) do
      expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.count }.by(1)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ borrowing.reader.email ])
    expect(mail.body.encoded).to include(borrowing.book.title)
    expect(mail.body.encoded).to include(borrowing.formatted_due_date)
  end

  it "sends distinguishable reminders for due-soon and due-today" do
    due_soon_borrowing = travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }
    due_today_borrowing = travel_to(Time.zone.local(2025, 12, 29)) { create(:borrowing) }

    travel_to(due_soon_borrowing.due_at - 3.days) do
      expect(due_today_borrowing.due_at.to_date).to eq(Date.current)
      described_class.perform_now
    end

    subjects = ActionMailer::Base.deliveries.map(&:subject)
    expect(subjects).to include(a_string_matching(/3 days/))
    expect(subjects).to include(a_string_matching(/today/))
  end

  it "sends nothing when nothing is due" do
    travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }

    travel_to(Time.zone.local(2026, 1, 2)) do
      expect { described_class.perform_now }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  it "sends each reminder only once when run twice in the same day" do
    borrowing = travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }

    travel_to(borrowing.due_at) do
      described_class.perform_now

      expect { described_class.perform_now }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  it "sends no reminder for a borrowing that has already been returned" do
    borrowing = travel_to(Time.zone.local(2026, 1, 1)) { create(:borrowing) }

    travel_to(borrowing.due_at - 1.day) { borrowing.return! }

    travel_to(borrowing.due_at) do
      expect { described_class.perform_now }.not_to change { ActionMailer::Base.deliveries.count }
    end
  end

  it "sends one reminder per book to a reader with two books due the same day" do
    reader = create(:reader)

    travel_to(Time.zone.local(2026, 1, 1)) do
      create(:borrowing, reader:, book: create(:book))
      create(:borrowing, reader:, book: create(:book))
    end

    travel_to(Time.zone.local(2026, 1, 1).beginning_of_day + 30.days) do
      expect { described_class.perform_now }.to change { ActionMailer::Base.deliveries.count }.by(2)
    end

    recipients = ActionMailer::Base.deliveries.map { |mail| mail.to.first }
    expect(recipients).to eq([ reader.email, reader.email ])
  end
end
