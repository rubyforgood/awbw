require 'rails_helper'

RSpec.describe "people/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:person) { create(:person, pronouns: "sdfsdf") }

  before(:each) do
    assign(:person, person)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
    render
  end

  it "displays the edit heading" do
    expect(rendered).to match(/Edit Person/)
  end

  it "has a form with the person fields" do
    expect(rendered).to have_field('First name', with: person.first_name)
    expect(rendered).to have_field('Last name', with: person.last_name)
    expect(rendered).to have_field('Pronouns', with: person.pronouns)
    expect(rendered).to have_checked_field('person_profile_show_pronouns') if person.profile_show_pronouns
  end

  it "has a link to the show page" do
    expect(rendered).to have_link('Profile', href: person_path(person))
  end

  it "has a link back to change password" do
    expect(rendered).to have_link('Change password', href: change_password_path)
  end
end
