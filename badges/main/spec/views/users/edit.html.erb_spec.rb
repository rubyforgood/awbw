require 'rails_helper'

RSpec.describe "users/edit", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) } # or super_user trait

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(admin_user) # Stub current_user for Devise
  end

  it "renders the edit user form with all fields" do
    render

    assert_select "form[action=?][method=?]", user_path(user), "post" do
      # Inputs
      %w[
        first_name last_name email
        state state2 zip zip2 phone phone2 phone3 best_time_to_call
        inactive super_user
      ].each do |field|
        assert_select "input[name=?]", "user[#{field}]"
      end

      # Textareas
      %w[address address2 city city2 notes].each do |field|
        assert_select "textarea[name=?]", "user[#{field}]"
      end
    end
  end
end
