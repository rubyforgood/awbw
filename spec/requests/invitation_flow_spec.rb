require 'rails_helper'

RSpec.describe "Invitation Flow", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:new_user) { create(:user, confirmed_at: nil, email: "newuser@example.com") }

  before do
    sign_in admin
  end

  it "allows admin to invite user and user to confirm and set password" do
    # Step 1: Admin sends invitation
    post send_welcome_instructions_user_path(new_user), params: {
      search: "newuser@example.com",
      super_user: "0",
      inactive: "0",
      page: "2",
      number_of_items_per_page: "50"
    }
    expect(response).to redirect_to(users_path(search: "newuser@example.com",
                                               super_user: "0",
                                               inactive: "0",
                                               page: "2",
                                               number_of_items_per_page: "50"))

    # Verify user has welcome token and confirmation token
    new_user.reload
    expect(new_user.welcome_instructions_token).to be_present
    expect(new_user.welcome_instructions_sent_at).to be_present
    expect(new_user.confirmation_token).to be_present
    expect(new_user.confirmed_at).to be_nil

    confirmation_token = new_user.confirmation_token

    # Step 2: User clicks confirmation link (simulating email click)
    sign_out admin
    get user_confirmation_path(confirmation_token: confirmation_token)

    # Should redirect to welcome page
    expect(response).to redirect_to(user_welcome_path(new_user.reload.welcome_instructions_token))

    # User should now be confirmed
    expect(new_user.reload.confirmed_at).to be_present

    # Step 3: User sets password on welcome page
    welcome_token = new_user.welcome_instructions_token
    patch user_welcome_update_path(welcome_token), params: {
      user: {
        password: "NewSecurePassword123!",
        password_confirmation: "NewSecurePassword123!"
      }
    }

    # Should be logged in and redirected to root
    expect(response).to redirect_to(root_path)
    expect(controller.current_user).to eq(new_user)

    # Welcome token should be cleared
    expect(new_user.reload.welcome_instructions_token).to be_nil
  end
end
