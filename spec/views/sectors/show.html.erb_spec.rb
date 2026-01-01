require 'rails_helper'

RSpec.describe "sectors/show", type: :view do
  let(:admin) { create(:user, :admin) }

  before(:each) do
    assign(:sector, create(:sector, name: "Name", published: false))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/false/)
  end
end
