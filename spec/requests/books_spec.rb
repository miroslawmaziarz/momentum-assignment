require "rails_helper"

RSpec.describe "Books" do
  describe "GET /books" do
    it "lists the whole catalogue in serial number order" do
      create(:book, serial_number: "000300", title: "Piranesi")
      create(:book, serial_number: "000100", title: "Dune")
      create(:book, serial_number: "000200", title: "Solaris")

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.pluck("serial_number")).to eq(%w[000100 000200 000300])
    end

    it "succeeds with an empty list when the library holds no books" do
      get "/books"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "reports each book's status, derived from whether it is currently out" do
      out = create(:book, serial_number: "000100")
      create(:borrowing, book: out)
      on_the_shelf = create(:book, serial_number: "000200")

      get "/books"

      by_serial = response.parsed_body.index_by { |book| book["serial_number"] }
      expect(by_serial["000100"]).to include("status" => "borrowed")
      expect(by_serial["000200"]).to include("status" => "available")
    end

    it "fetches the catalogue's status in a constant number of queries" do
      3.times { |n| create(:borrowing, book: create(:book, serial_number: format("1%05d", n))) }
      small_catalogue_queries = count_queries { get "/books" }

      10.times { |n| create(:borrowing, book: create(:book, serial_number: format("2%05d", n))) }
      large_catalogue_queries = count_queries { get "/books" }

      expect(large_catalogue_queries).to eq(small_catalogue_queries)
    end
  end

  describe "POST /books" do
    it "records a book and returns it" do
      post "/books", params: { book: { serial_number: "123456", title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include(
        "serial_number" => "123456",
        "title" => "Dune",
        "author" => "Frank Herbert"
      )
    end

    it "accepts a JSON request body" do
      post "/books",
           params: { book: { serial_number: "123456", title: "Dune", author: "Frank Herbert" } },
           as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("serial_number" => "123456", "title" => "Dune")
    end

    it "assigns an unused six-digit serial number when none is given" do
      post "/books", params: { book: { title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:created)
      assigned = response.parsed_body["serial_number"]
      expect(assigned).to match(/\A\d{6}\z/)

      get "/books/#{assigned}"
      expect(response.parsed_body).to include("title" => "Dune")
    end

    it "rejects a serial number that is already in use, naming the offending field" do
      create(:book, serial_number: "123456")

      post "/books", params: { book: { serial_number: "123456", title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("serial_number")
    end

    it "rejects a serial number that is not exactly six digits" do
      post "/books", params: { book: { serial_number: "12345", title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details")).to include("serial_number")
    end

    it "reports every invalid field at once, so a request can be fixed in one pass" do
      post "/books", params: { book: { serial_number: "not-a-serial" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "details").keys)
        .to contain_exactly("serial_number", "title", "author")
    end

    it "reports a request with no book parameters as a bad request" do
      post "/books", params: {}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "does not leak the framework's parameter wording into the message" do
      post "/books", params: {}

      expect(response.parsed_body.dig("error", "message")).not_to match(/permitted/i)
    end

    it "reports an unparseable request body as a bad request, in the same envelope" do
      post "/books", params: "{not json", headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to include("code" => "bad_request")
    end

    it "reports a serial number lost to a concurrent create as a validation failure" do
      create(:book, serial_number: "123456")
      allow_any_instance_of(Book).to receive(:save!)
        .and_raise(ActiveRecord::RecordNotUnique, "duplicate key")

      post "/books", params: { book: { serial_number: "123456", title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "details")).to include("serial_number")
    end

    it "keeps the leading zeros of a serial number through a create-then-fetch round trip" do
      post "/books", params: { book: { serial_number: "000123", title: "Dune", author: "Frank Herbert" } }
      expect(response.parsed_body).to include("serial_number" => "000123")

      get "/books/000123"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("serial_number" => "000123")
    end
  end

  describe "GET /books/:serial_number" do
    it "returns the book printed with that serial number" do
      create(:book, serial_number: "654321", title: "Piranesi", author: "Susanna Clarke")

      get "/books/654321"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(
        "serial_number" => "654321",
        "title" => "Piranesi",
        "author" => "Susanna Clarke"
      )
    end

    it "reports a serial number the library does not hold as not found" do
      get "/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
      expect(response.parsed_body.dig("error", "message")).to be_present
    end

    it "reports a serial number that is not six digits as not found, in the same envelope" do
      get "/books/nonsense"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end

    it "reports a currently borrowed book as borrowed, with the open loan open in its history" do
      book = create(:book, serial_number: "123456")
      reader = create(:reader, card_number: "654321", full_name: "Ada Lovelace")
      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) { create(:borrowing, book:, reader:) }

      get "/books/123456"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "borrowed")
      expect(response.parsed_body["history"].length).to eq(1)
      expect(response.parsed_body["history"].first).to include(
        "borrowed_at" => "2026-01-01T12:00:00.000Z",
        "due_at" => "2026-01-31T12:00:00.000Z",
        "returned_at" => nil
      )
      expect(response.parsed_body["history"].first["reader"]).to include(
        "card_number" => "654321",
        "full_name" => "Ada Lovelace",
        "email" => reader.email
      )
    end

    it "reports a previously returned book as available, with the closed loan in its history" do
      book = create(:book, serial_number: "123456")
      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) { create(:borrowing, :returned, book:) }

      get "/books/123456"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "available")
      expect(response.parsed_body["history"].first).to include("returned_at" => "2026-01-01T12:00:00.000Z")
    end

    it "returns an empty history for a book that has never been borrowed" do
      create(:book, serial_number: "123456")

      get "/books/123456"

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("status" => "available", "history" => [])
    end

    it "orders history most-recent-first, so the latest loan reads first" do
      book = create(:book, serial_number: "123456")
      travel_to(Time.zone.local(2026, 1, 1, 12, 0, 0)) { create(:borrowing, :returned, book:) }
      travel_to(Time.zone.local(2026, 3, 1, 12, 0, 0)) { create(:borrowing, book:) }

      get "/books/123456"

      expect(response.parsed_body["history"].pluck("borrowed_at")).to eq(
        %w[2026-03-01T12:00:00.000Z 2026-01-01T12:00:00.000Z]
      )
    end
  end

  describe "DELETE /books/:serial_number" do
    it "deletes a book that is not currently borrowed, and it disappears from the catalogue" do
      create(:book, serial_number: "123456")

      delete "/books/123456"

      expect(response).to have_http_status(:no_content)

      get "/books/123456"
      expect(response).to have_http_status(:not_found)
    end

    it "refuses to delete a book that is currently out with a reader, explaining why" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, book:)

      delete "/books/123456"

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("code" => "validation_failed")
      expect(response.parsed_body.dig("error", "message")).to match(/borrowed/i)

      get "/books/123456"
      expect(response).to have_http_status(:ok)
    end

    it "deletes a book that has past, fully-returned borrowings, taking that history with it" do
      book = create(:book, serial_number: "123456")
      create(:borrowing, :returned, book:)

      delete "/books/123456"

      expect(response).to have_http_status(:no_content)
      expect(Borrowing.where(book_id: book.id)).to be_empty
    end

    it "reports a serial number that does not exist as not found" do
      delete "/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body["error"]).to include("code" => "not_found")
    end

    it "frees a deleted book's serial number for reuse by a new book" do
      create(:book, serial_number: "123456")
      delete "/books/123456"

      post "/books", params: { book: { serial_number: "123456", title: "Dune", author: "Frank Herbert" } }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include("serial_number" => "123456", "title" => "Dune")
    end
  end
end
