# spec/views/users/new.html.erb_spec.rb
require 'rails_helper'

RSpec.describe "users/new.html.erb", type: :view do
  let(:user) { User.new }
  let(:admin) { create(:user, :admin) }

  before do
    assign(:user, user)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
    render
  end

  it "renders new user form" do
    render

    assert_select "form[action=?][method=?]", users_path, "post" do
      assert_select "input[name=?]", "user[email]"
      assert_select "input[name=?]", "user[super_user]"
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
