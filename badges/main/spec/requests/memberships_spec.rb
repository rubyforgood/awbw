require "rails_helper"

RSpec.describe "Memberships index", type: :request do
  before { sign_in create(:user, :admin) }

  it "lists memberships and links to the year report" do
    person = create(:person, :without_user, first_name: "Index", last_name: "Member")
    create(:membership, person:, start_date: Date.current, end_date: 1.year.from_now.to_date)

    get memberships_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Year report")

    get memberships_path, headers: { "Turbo-Frame" => "memberships_results" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Index Member")
    expect(response.body).not_to include("Revenue brought in")
  end
end
