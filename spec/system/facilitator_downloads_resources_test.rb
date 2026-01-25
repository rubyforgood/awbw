require 'rails_helper'

RSpec.describe "Facilitators can download resources", type: :system, js: true do
  let(:user) { create(:user) }
  let(:resource) do
    create(:resource,
           title: "Test Template",
           featured: true,
           inactive: false,
           kind: "Template")
  end

  before do
    create(:facilitator, user: user)
    create(:downloadable_asset, owner: resource)
  end

  describe "when user is logged in" do
    before { sign_in user }

    context "from the dashboard" do
      it "downloads the resource" do
        visit root_path

        find("a[href='#{resource_download_path(resource_id: resource.id)}']").click

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end

    context "from the resources index page" do
      it "downloads the resource" do
        visit resources_path

        find("a[href='#{resource_download_path(resource_id: resource.id)}']").click

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end

    context "when visiting download path directly" do
      it "downloads the resource" do
        visit resource_download_path(resource_id: resource.id)

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end
  end
end
