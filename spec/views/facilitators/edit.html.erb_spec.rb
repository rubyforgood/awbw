require 'rails_helper'

RSpec.describe "facilitators/edit", type: :view do
    let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  let(:facilitator) { create(:facilitator, pronouns: "sdfsdf")}

  before(:each) do
    assign(:facilitator, facilitator)
    allow(view).to receive(:current_user).and_return(admin)
    render
  end

  it "displays the edit heading" do
    expect(rendered).to match(/Edit Facilitator/)
  end

  it "has a form with the facilitator fields" do
    expect(rendered).to have_field('First name', with: facilitator.user.first_name)
    expect(rendered).to have_field('Last name', with: facilitator.user.last_name)
    expect(rendered).to have_field('Pronouns', with: facilitator.pronouns)
    expect(rendered).to have_checked_field('facilitator_profile_show_pronouns') if facilitator.profile_show_pronouns
  end

  it "has a link to the show page" do
    expect(rendered).to have_link('Profile', href: facilitator_path(facilitator))
  end

  it "has a link back to change password" do
    expect(rendered).to have_link('Change password', href: change_password_path)
  end
end
