require "rails_helper"

RSpec.describe "Borrowings" do
  describe "POST /books/:serial_number/borrowings" do
    it "lends the book to the reader holding that card" do
      create(:book, serial_number: "123456", title: "Dune")
      create(:reader, card_number: "654321", full_name: "Ada Lovelace")

      post "/books/123456/borrowings", params: { borrowing: { card_number: "654321" } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("serial_number" => "123456", "returned_at" => nil)
      expect(response.parsed_body["reader"]).to include(
        "card_number" => "654321",
        "full_name" => "Ada Lovelace"
      )
    end

    it "accepts a card number sent unwrapped, as the other endpoints do" do
      create(:book, serial_number: "123456")
      create(:reader, card_number: "654321")

      post "/books/123456/borrowings", params: { card_number: "654321" }, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["reader"]).to include("card_number" => "654321")
    end

    it "sets the due date thirty days after lending" do
      create(:book, serial_number: "123456")
      create(:reader, card_number: "654321")

      travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
        post "/books/123456/borrowings", params: { borrowing: { card_number: "654321" } }
      end

      expect(response.parsed_body["borrowed_at"]).to eq("2026-01-01T12:00:00.000Z")
      expect(response.parsed_body["due_at"]).to eq("2026-01-31T12:00:00.000Z")
    end

    it "ignores a due date supplied by the client" do
      create(:book, serial_number: "123456")
      create(:reader, card_number: "654321")

      travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
        post "/books/123456/borrowings",
             params: { borrowing: { card_number: "654321", due_at: "2027-01-01T12:00:00Z" } }
      end

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["due_at"]).to eq("2026-01-31T12:00:00.000Z")
    end

    it "refuses to lend a book that is already out" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, book:)
      create(:reader, card_number: "654321")

      post "/books/123456/borrowings", params: { borrowing: { card_number: "654321" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "reports an unknown card number as not found" do
      create(:book, serial_number: "123456")

      post "/books/123456/borrowings", params: { borrowing: { card_number: "999999" } }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end

    it "reports an unknown serial number as not found" do
      create(:reader, card_number: "654321")

      post "/books/999999/borrowings", params: { borrowing: { card_number: "654321" } }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end

    it "reports a request with no card number as a bad request" do
      create(:book, serial_number: "123456")

      post "/books/123456/borrowings", params: { borrowing: {} }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request")
    end

    it "reports a book deleted out from under a concurrent lend as not found" do
      create(:book, serial_number: "123456")
      create(:reader, card_number: "654321")
      allow_any_instance_of(Borrowing).to receive(:save!)
        .and_raise(ActiveRecord::InvalidForeignKey, "violates foreign key constraint")

      post "/books/123456/borrowings", params: { borrowing: { card_number: "654321" } }

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end
  end

  describe "POST /books/:serial_number/borrowings/return" do
    it "records the book as returned" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, book:)

      travel_to Time.zone.local(2026, 2, 1, 9, 0, 0) do
        post "/books/123456/borrowings/return"
      end

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "serial_number" => "123456",
        "returned_at" => "2026-02-01T09:00:00.000Z"
      )
    end

    it "closes the open borrowing rather than creating a second one" do
      book = create(:book, serial_number: "123456")
      borrowed_at = Time.zone.local(2026, 1, 1, 12, 0, 0)
      travel_to(borrowed_at) { create(:borrowing, book:) }

      post "/books/123456/borrowings/return"

      expect(response.parsed_body["borrowed_at"]).to eq("2026-01-01T12:00:00.000Z")
      expect(response.parsed_body["due_at"]).to eq("2026-01-31T12:00:00.000Z")
    end

    it "puts the book back on the shelf, so it can be lent again" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, book:)
      create(:reader, card_number: "654321")

      post "/books/123456/borrowings/return"
      post "/books/123456/borrowings", params: { borrowing: { card_number: "654321" } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["reader"]).to include("card_number" => "654321")
    end

    it "refuses to return a book that is not currently out" do
      create(:book, serial_number: "123456")

      post "/books/123456/borrowings/return"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "refuses a second return of the same loan" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, book:)

      post "/books/123456/borrowings/return"
      post "/books/123456/borrowings/return"

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reports an unknown serial number as not found" do
      post "/books/999999/borrowings/return"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end
  end
end
