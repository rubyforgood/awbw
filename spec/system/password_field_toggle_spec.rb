require "rails_helper"

RSpec.describe "Password field toggle", type: :system do
  include Rails.application.routes.url_helpers

  it "toggles password visibility on the login page" do
    visit new_user_session_path
    expect(page).to have_css("[data-action='password-toggle#toggle']", wait: 5)

    password_field = find("input[type='password']")
    password_field.set("my_secure_password")
    expect(password_field[:type]).to eq("password")

    find(".toggle-password .fa-eye").click
    expect(password_field[:type]).to eq("text")
    expect(password_field.value).to eq("my_secure_password")
  end

  it "toggles password visibility on the set password page" do
    visit edit_user_password_path(reset_password_token: "dummy_token")
    expect(page).to have_css("[data-action='password-toggle#toggle']", wait: 5)

    %w[user_password user_password_confirmation].each do |field_id|
      password_field = find("input##{field_id}")
      password_field.set("my_secure_password")
      expect(password_field[:type]).to eq("password")

      find(".toggle-password .fa-eye", match: :first).click
      expect(password_field[:type]).to eq("text")
      expect(password_field.value).to eq("my_secure_password")
    end
  end

  it "toggles password visibility on the change password page" do
    user = create(:user)
    sign_in user
    visit change_password_path

    # There should be exactly 3 password-toggle controllers
    expect(page).to have_css("[data-controller='password-toggle']", count: 3)

    all("[data-controller='password-toggle']").each do |wrapper|
      within(wrapper) do
        input = find("input[type='password']", visible: true)
        eye_toggle = find("[data-action='password-toggle#toggle']")

        input.set("my_secure_password")
        expect(input[:type]).to eq("password")

        eye_toggle.click

        # Wait for JS mutation
        expect { input[:type] }.to eventually(eq("text"))
        expect(input.value).to eq("my_secure_password")
      end
    end
  end
end
