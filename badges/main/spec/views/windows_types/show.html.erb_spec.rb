require 'rails_helper'

RSpec.describe "windows_types/show", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:windows_type) { create(:windows_type, name: "Adult", short_name: "ADULT") }

  before(:each) do
    assign(:windows_type, windows_type)
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to include(/ADULT/)
  end
end
