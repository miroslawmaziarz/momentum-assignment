require "rails_helper"

# The health endpoint is what tells a reviewer — or a container orchestrator — that the app
# is not merely listening on a port but can actually reach its database. Asserting on the
# body, not just the status, is the point: a 200 from a Rails app that cannot query
# PostgreSQL would be a lie.
RSpec.describe "GET /health" do
  before { get "/health" }

  it "reports the application as healthy" do
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("status" => "ok")
  end

  it "confirms it can reach the database" do
    expect(response.parsed_body).to include("database" => "connected")
  end

  it "responds as JSON" do
    expect(response.media_type).to eq("application/json")
  end
end
