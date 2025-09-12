require 'rails_helper'

RSpec.describe 'User login', type: :system do

  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

  let!(:user) { create(:user) }

  it 'logs the user in with valid credentials' do
    visit new_user_session_path

    fill_in 'Email', with: user.email
    fill_in 'Password', with: 'password'

    click_button 'Log in'

    expect(page).to have_css('.avatar')
  end
end
