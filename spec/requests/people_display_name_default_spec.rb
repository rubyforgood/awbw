require "rails_helper"

RSpec.describe "Person display name default option", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person).tap { |p| p.update_column(:display_name_preference, nil) } }

  before { sign_in admin }

  it "selects the default option for a person who never picked a format" do
    get edit_person_path(person)

    select = Nokogiri::HTML(response.body).at_css("select#person_display_name_preference")
    expect(select.at_css("option[selected]")).to be_nil
    expect(select.at_css("option").then { |first| [ first["value"], first.text ] })
      .to eq([ "", "Default (First name and last initial)" ])
  end

  it "keeps an unchosen format blank so it follows the default" do
    patch person_path(person), params: { person: { display_name_preference: "" } }

    expect(person.reload.read_attribute(:display_name_preference)).to be_nil
  end

  it "saves an explicit pick" do
    patch person_path(person), params: { person: { display_name_preference: "full_name" } }

    expect(person.reload.display_name_preference).to eq("full_name")
  end
end
