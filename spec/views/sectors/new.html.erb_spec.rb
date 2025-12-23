require 'rails_helper'

RSpec.describe "sectors/new", type: :view do
  before do
    assign(:sector, Sector.new)
  end

  it "renders the new sector form" do
    render

    assert_select "form[action='#{sectors_path}']" do
      assert_select "input[name='sector[name]']"
      assert_select "input[name='sector[published]']"
    end
  end
end
