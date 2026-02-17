require 'rails_helper'

RSpec.describe "users/change_password", type: :view do
  let(:user) { create(:user) }

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(user)
    render
  end

  it "displays password requirements hint" do
    expect(rendered).to have_content("Password must be at least 5 characters long")
  end

  it "has minlength attribute on password field" do
    expect(rendered).to have_css('input[type="password"][minlength="5"]#change-password-new-password')
  end

  it "displays current password field" do
    expect(rendered).to have_field("Current password", type: :password)
  end

  it "displays new password field" do
    expect(rendered).to have_field("New password", type: :password)
  end

  it "displays password confirmation field" do
    expect(rendered).to have_field("New password confirmation", type: :password)
  end

  it "has a submit button" do
    expect(rendered).to have_button("Change Password")
  end

  context "when user has password errors" do
    before do
      user.errors.add(:password, "is too short (minimum is 5 characters)")
      user.errors.add(:current_password, "is invalid")
      render
    end

    it "displays error messages" do
      expect(rendered).to have_content("There was a problem with your password")
      expect(rendered).to have_content("Password is too short")
      expect(rendered).to have_content("Current password is invalid")
    end

    it "displays error alert with proper styling" do
      expect(rendered).to have_css('div[role="alert"]#password-errors')
    end
  end
end
