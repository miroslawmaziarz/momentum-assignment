require "rails_helper"

RSpec.describe "Readers" do
  describe "GET /readers" do
    it "lists every registered reader in card number order" do
      create(:reader, card_number: "000300", full_name: "Grace Hopper")
      create(:reader, card_number: "000100", full_name: "Ada Lovelace")
      create(:reader, card_number: "000200", full_name: "Alan Turing")

      get "/readers"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("card_number")).to eq(%w[000300 000100 000200])
    end

    it "succeeds with an empty list when nobody is registered" do
      get "/readers"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end
  end

  describe "GET /readers/:card_number" do
    it "returns the reader holding that card" do
      create(:reader, card_number: "654321", full_name: "Ada Lovelace", email: "ada@example.com")

      get "/readers/654321"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "card_number" => "654321",
        "full_name" => "Ada Lovelace",
        "email" => "ada@example.com"
      )
    end

    it "reports a card number nobody holds as not found" do
      get "/readers/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "reports a card number that is not six digits as not found, in the same envelope" do
      get "/readers/nonsense"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end
  end

  describe "POST /readers" do
    it "registers a reader and returns them" do
      post "/readers",
           params: { reader: { card_number: "123456", full_name: "Ada Lovelace", email: "ada@example.com" } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "card_number" => "123456",
        "full_name" => "Ada Lovelace",
        "email" => "ada@example.com"
      )
    end

    it "assigns an unused six-digit card number when none is given" do
      post "/readers", params: { reader: { full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:created)
      assigned = response.parsed_body["card_number"]
      expect(assigned).to match(/\A\d{6}\z/)

      get "/readers/#{assigned}"
      expect(response.parsed_body).to include("full_name" => "Ada Lovelace")
    end

    it "rejects a card number that is already in use, naming the offending field" do
      create(:reader, card_number: "123456")

      post "/readers",
           params: { reader: { card_number: "123456", full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("card_number")
    end

    it "rejects a card number that is not exactly six digits" do
      post "/readers",
           params: { reader: { card_number: "12345", full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("card_number")
    end

    it "rejects an email address already registered to another reader" do
      create(:reader, email: "ada@example.com")

      post "/readers",
           params: { reader: { full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("email")
    end

    it "rejects an email address that differs from an existing one only by letter case" do
      create(:reader, email: "ada@example.com")

      post "/readers",
           params: { reader: { full_name: "Ada Lovelace", email: "ADA@Example.COM" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("email")
    end

    it "rejects a malformed email address" do
      post "/readers",
           params: { reader: { full_name: "Ada Lovelace", email: "ada-at-example" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("email")
    end

    it "reports every invalid field at once, so a request can be fixed in one pass" do
      post "/readers", params: { reader: { card_number: "not-a-card" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details").keys)
        .to contain_exactly("card_number", "full_name", "email")
    end

    it "stores an address as typed apart from case and surrounding space" do
      post "/readers", params: { reader: { full_name: "Ada Lovelace", email: "  ADA@Example.COM " } }

      expect(response.parsed_body).to include("email" => "ada@example.com")
    end

    it "reports a request with no reader parameters as a bad request" do
      post "/readers", params: {}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "reports a card number lost to a concurrent registration as a validation failure" do
      create(:reader, card_number: "123456")
      allow_any_instance_of(Reader).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique, "duplicate key")

      post "/readers",
           params: { reader: { card_number: "123456", full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("card_number")
    end

    it "names the email address when that is what a concurrent registration took" do
      create(:reader, email: "ada@example.com")
      allow_any_instance_of(Reader).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique, "duplicate key")

      post "/readers", params: { reader: { full_name: "Ada Lovelace", email: "ada@example.com" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("email")
    end
  end
end
