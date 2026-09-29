require "rails_helper"

RSpec.describe "People multiple-memberships warning", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  # Two uncancelled memberships is the state a merge leaves behind (it moves rows
  # with update_all, bypassing the one-uncancelled validation), so build it the same
  # way here.
  def two_uncancelled_memberships(person)
    create(:membership, person: person)
    build(:membership, person: person).save!(validate: false)
  end

  it "flags a person with more than one active membership on the index" do
    person = create(:person, first_name: "Manny")
    two_uncancelled_memberships(person)

    get people_path, headers: turbo_headers

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Multiple memberships")
  end

  it "does not flag a person with a single active membership plus a cancelled one" do
    person = create(:person, first_name: "Solo")
    create(:membership, person: person)
    create(:membership, :cancelled, person: person)

    get people_path, headers: turbo_headers

    expect(response.body).not_to include("Multiple memberships")
  end

  it "flags a person with more than one active membership on show and edit" do
    person = create(:person)
    two_uncancelled_memberships(person)

    get person_path(person)
    expect(response.body).to include("Multiple memberships")

    get edit_person_path(person)
    expect(response.body).to include("Multiple memberships")
  end
end
