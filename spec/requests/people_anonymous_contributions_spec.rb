require "rails_helper"

RSpec.describe "Person anonymous contributions setting", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  it "renders the anonymous-contributions toggle on the edit form" do
    get edit_person_path(person)

    expect(response.body).to include("Contribute anonymously")
  end

  it "persists the anonymous-contributions setting on update" do
    patch person_path(person), params: { person: { anonymous_contributions: "1" } }

    expect(person.reload.anonymous_contributions).to be(true)
  end
end
