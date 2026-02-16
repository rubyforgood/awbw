require 'rails_helper'

RSpec.describe "users/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user, :admin) } # or super_user trait

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(admin_user) # Stub current_user for Devise
    allow(view).to receive(:allowed_to?).and_return(true)
  end

  it "renders the edit user form with all fields" do
    render

    assert_select "form[action=?][method=?]", user_path(user), "post" do
      %w[ email locked super_user ].each do |field|
        assert_select "input[name=?]", "user[#{field}]"
      end
    end
  end

  it "renders the comments section" do
    render

    assert_select "#comments-section" do
      assert_select ".font-semibold", text: "Comments"
    end
  end

  context "when params[:admin] is present" do
    before do
      allow(view).to receive(:params).and_return(ActionController::Parameters.new(admin: "true"))
    end

    it "renders the legacy comment field" do
      render

      assert_select "textarea[name=?]", "user[comment]"
    end
  end
end
