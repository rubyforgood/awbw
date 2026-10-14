require "rails_helper"

RSpec.describe "Choosing what others see", type: :system, js: true do
  let(:user) { create(:user, :with_person) }
  let(:person) { user.person }

  before { sign_in user }

  it "saves every switch and the name choice from the page" do
    labels = [
      "Let other AWBW facilitators find and see your profile",
      "Stay anonymous on stories, workshops, and variations you write"
    ] + PersonDecorator::PROFILE_VISIBILITY_GROUPS.values.flat_map(&:values)
    attributes = %i[profile_is_searchable anonymous_contributions] +
      PersonDecorator::PROFILE_VISIBILITY_GROUPS.values.flat_map(&:keys)
    original = attributes.index_with { |attribute| person.public_send(attribute) }

    visit visibility_person_path(person)
    labels.each { |label| find("label", text: label, exact_text: false).click }
    find("label", text: "First name only").click
    click_button "Save"

    expect(page).to have_current_path(person_path(person))
    person.reload
    original.each { |attribute, value| expect(person.public_send(attribute)).to eq(!value), attribute.to_s }
    expect(person.display_name_preference).to eq("first_name_only")
  end
end
