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

  it "has a link to the change password page" do
    expect(rendered).to have_link('Change password', href: change_password_path)
  end

  it "has a link to the dashboard" do
    expect(rendered).to have_link('Dashboard', href: root_path)
  end

  context "when person has an associated user" do
    it "displays the user's email as read-only" do
      expect(rendered).to have_content(person.user.email)
      expect(rendered).not_to have_field('Primary email')
    end

    it "displays the user's email type as read-only" do
      expect(rendered).to have_content(person.user.email_type)
    end
  end

  context "when person does not have an associated user" do
    let(:person_without_user) { create(:person, user: nil, pronouns: "they/them", email: "test@example.com") }

    before(:each) do
      assign(:person, person_without_user)
      render
    end

    it "displays an editable email field" do
      expect(rendered).to have_field('Primary email', with: person_without_user.email)
    end

    it "displays an editable email type field" do
      expect(rendered).to have_select('Primary email type')
    end
  end
end
