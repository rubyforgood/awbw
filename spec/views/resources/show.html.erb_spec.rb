require "rails_helper"

RSpec.describe "resources/show", type: :view do
  let(:admin) { create(:user, :admin) }
  let(:resource) { create(:resource, :published, user: admin) }

  before do
    sign_in admin
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(true)
    assign(:resource, resource.decorate)
  end

  context "when resource has an attached primary image" do
    let(:primary_asset) do
      create(:primary_asset, :with_file, owner: resource)
    end

    before do
      primary_asset
      resource.reload
      render
    end

    it "wraps the hero image in a link that opens in a new tab" do
      expect(rendered).to have_css("a.display-image-link[target='_blank'][rel='noopener noreferrer']")
    end
  end

  context "when resource has no attached image" do
    before { render }

    it "renders without errors" do
      expect(rendered).to have_text(resource.title)
    end
  end
end
