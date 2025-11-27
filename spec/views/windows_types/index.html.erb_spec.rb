require 'rails_helper'

RSpec.describe "windows_types/index", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:windows_type1) { create(:windows_type, name: "Adult", short_name: "ADULT") }
  let(:windows_type2) { create(:windows_type, name: "Children", short_name: "CHILDREN") }

  before(:each) do
    assign(:windows_types, paginated([windows_type1, windows_type2]))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders a list of story_ideas" do
    render
    expect(rendered).to include(windows_type1.short_name, windows_type2.short_name)
  end

  it "renders a friendly message when no workshop_ideas exist" do
    assign(:windows_types, paginated([]))
    render
    expect(rendered).to match(/No Windows types found/)
  end
end
