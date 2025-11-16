require 'rails_helper'

RSpec.describe "banners/edit", type: :view do
    let(:admin) { create(:user, :admin) }

  let(:banner) {
    Banner.create!(
      content: "MyText",
      show: false,
      created_by: admin,
      updated_by: admin
    )
  }

  before(:each) do
    assign(:banner, banner)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders the edit banner form" do
    render

    assert_select "form[action=?][method=?]", banner_path(banner), "post" do

      assert_select "textarea[name=?]", "banner[content]"

      assert_select "input[name=?]", "banner[show]"

      assert_select "input[name=?]", "banner[created_by_id]"

      assert_select "input[name=?]", "banner[updated_by_id]"
    end
  end
end
