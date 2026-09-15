require "rails_helper"

RSpec.describe "Book status updates" do
  describe "PATCH /books/:serial_number, setting status to \"borrowed\"" do
    it "lends the book to the reader holding that card, exactly as the borrow endpoint would" do
      reader = create(:reader, card_number: "654321")
      create(:book, serial_number: "111111")
      create(:book, serial_number: "222222")

      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) do
        post "/books/111111/borrowings", params: { borrowing: { card_number: reader.card_number } }
      end
      direct_status = response.status
      direct_body = response.parsed_body

      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) do
        patch "/books/222222", params: { status: "borrowed", card_number: reader.card_number }, as: :json
      end

      expect(response.status).to eq(direct_status)
      expect(response.parsed_body.except("serial_number")).to eq(direct_body.except("serial_number"))
    end

    it "refuses to lend a book that is already out, exactly as the borrow endpoint would" do
      reader = create(:reader, card_number: "654321")
      direct = create(:book, serial_number: "111111")
      create(:borrowing, book: direct)
      aliased = create(:book, serial_number: "222222")
      create(:borrowing, book: aliased)

      post "/books/111111/borrowings", params: { borrowing: { card_number: reader.card_number } }
      direct_status = response.status
      direct_body = response.parsed_body

      patch "/books/222222", params: { status: "borrowed", card_number: reader.card_number }, as: :json

      expect(response.status).to eq(direct_status)
      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq(direct_body)
    end

    it "refuses a borrow with no card number, with a clear message" do
      create(:book, serial_number: "123456")

      patch "/books/123456", params: { status: "borrowed" }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "reports an unknown card number as not found, exactly as the borrow endpoint would" do
      create(:book, serial_number: "111111")
      create(:book, serial_number: "222222")

      post "/books/111111/borrowings", params: { borrowing: { card_number: "999999" } }
      direct_status = response.status
      direct_body = response.parsed_body

      patch "/books/222222", params: { status: "borrowed", card_number: "999999" }, as: :json

      expect(response.status).to eq(direct_status)
      expect(response.parsed_body).to eq(direct_body)
    end
  end

  describe "PATCH /books/:serial_number, setting status to \"available\"" do
    it "returns the book, exactly as the return endpoint would" do
      reader = create(:reader, card_number: "654321")
      direct = create(:book, serial_number: "111111")
      aliased = create(:book, serial_number: "222222")

      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) do
        create(:borrowing, book: direct, reader:)
        create(:borrowing, book: aliased, reader:)
      end

      travel_to(Time.zone.local(2026, 2, 1, 9, 0, 0)) { post "/books/111111/borrowings/return" }
      direct_status = response.status
      direct_body = response.parsed_body

      travel_to(Time.zone.local(2026, 2, 1, 9, 0, 0)) do
        patch "/books/222222", params: { status: "available" }, as: :json
      end

      expect(response.status).to eq(direct_status)
      expect(response.parsed_body.except("serial_number")).to eq(direct_body.except("serial_number"))
    end

    it "refuses to return a book that is not currently out, exactly as the return endpoint would" do
      create(:book, serial_number: "111111")
      create(:book, serial_number: "222222")

      post "/books/111111/borrowings/return"
      direct_status = response.status
      direct_body = response.parsed_body

      patch "/books/222222", params: { status: "available" }, as: :json

      expect(response.status).to eq(direct_status)
      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq(direct_body)
    end
  end

  describe "PATCH /books/:serial_number with an unrecognised status" do
    it "is refused rather than silently ignored" do
      create(:book, serial_number: "123456")

      patch "/books/123456", params: { status: "missing" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("status")
    end
  end

  it "reports an unknown serial number as not found" do
    patch "/books/999999", params: { status: "available" }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body["error"]).to include("code" => "not_found")
  end
end
