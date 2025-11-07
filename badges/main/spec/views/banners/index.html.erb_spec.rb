require 'rails_helper'

RSpec.describe "banners/index", type: :view do
  let!(:combined_perm) { create(:permission, :combined) }
  let!(:adult_perm)    { create(:permission, :adult) }
  let!(:children_perm) { create(:permission, :children) }
  let(:admin) { create(:user, :admin) }
  let(:banner1) { create(:banner) }
  let(:banner2) { create(:banner) }

  before(:each) do
    assign(:banners, paginated([banner1, banner2]))
    allow(view).to receive(:current_user).and_return(admin)
  end

  it "renders a list of story_ideas" do
    render
    expect(rendered).to include(banner1.content, banner2.content)
  end

  it "renders a friendly message when no banners exist" do
    assign(:banners, paginated([]))
    render
    expect(rendered).to match(/No Banners found/)
  end
end
