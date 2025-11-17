require 'rails_helper'

RSpec.describe "banners/new", type: :view do
    let(:admin) { create(:user, :admin) }

  before(:each) do
    assign(:banner, Banner.new(
      content: "MyText",
      show: false,
      created_by: admin,
      updated_by: admin
    ))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders new banner form" do
    render

    assert_select "form[action=?][method=?]", banners_path, "post" do

      assert_select "textarea[name=?]", "banner[content]"

      assert_select "input[name=?]", "banner[show]"

      assert_select "input[name=?]", "banner[created_by_id]"

      assert_select "input[name=?]", "banner[updated_by_id]"
    end
  end
end
