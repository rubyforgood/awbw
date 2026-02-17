require 'rails_helper'

RSpec.describe "devise/passwords/edit", type: :view do
  let(:user) { create(:user) }

  before do
    user.reset_password_token = Devise.friendly_token
    assign(:resource, user)
    assign(:resource_name, :user)
    u = user
    mapping = Devise.mappings[:user]
    view.define_singleton_method(:resource) { u }
    view.define_singleton_method(:resource_name) { :user }
    view.define_singleton_method(:devise_mapping) { mapping }
    render
  end

  it "displays new password field" do
    expect(rendered).to have_field("New password", type: :password)
  end

  it "displays password confirmation field" do
    expect(rendered).to have_field("Confirm new password", type: :password)
  end

  it "has a submit button" do
    expect(rendered).to have_button("Set password")
  end

  it "displays password requirements hint" do
    expect(rendered).to have_content("Password must be at least 5 characters long")
  end

  it "has minlength attribute on password field" do
    expect(rendered).to have_css('input[type="password"][minlength="5"]')
  end

  context "when user has password errors" do
    before do
      user.errors.add(:password, "is too short (minimum is 5 characters)")
      user.errors.add(:password_confirmation, "doesn't match Password")
      render
    end

    it "displays error explanation container" do
      expect(rendered).to have_css('div#error_explanation')
    end

    it "displays error messages" do
      expect(rendered).to have_content("prevented this from being saved")
      expect(rendered).to have_content("Password is too short")
      expect(rendered).to have_content("Password confirmation doesn't match")
    end
  end
end
