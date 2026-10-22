require "rails_helper"

RSpec.describe "Person email whitespace", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, user: nil, email: "jane@test.org", email_2: "jane2@test.org") }

  before { sign_in admin }

  it "renders a whitespace-only stored email as an empty field" do
    person.update_columns(email: "  ", email_2: "​")

    get edit_person_path(person)

    form = Nokogiri::HTML(response.body)
    expect(form.at_css("input[name='person[email]']")["value"].to_s).to eq("")
    expect(form.at_css("input[name='person[email_2]']")["value"].to_s).to eq("")
  end

  it "saves a submitted email with its whitespace removed" do
    patch person_path(person), params: { person: { email: "  new@test.org\t", email_2: "​ " } }

    expect(person.reload.email).to eq("new@test.org")
    expect(person.email_2).to eq("")
  end
end
