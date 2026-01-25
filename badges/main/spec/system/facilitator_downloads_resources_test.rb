require 'rails_helper'

RSpec.describe "Facilitators can download resources", type: :system, js: true do
  include DownloadHelpers

  let(:user) { create(:user) }
  let(:resource) do
    create(:resource,
           title: "Test Template",
           featured: true,
           inactive: false,
           kind: "Template")
  end

  before do
    Capybara.register_driver :selenium_chrome_headless_download do |app|
      browser_options = ::Selenium::WebDriver::Chrome::Options.new.tap do |opts|
        opts.args << '--headless'
        opts.args << '--disable-site-isolation-trials'
      end
      browser_options.add_preference(:download, prompt_for_download: false,
        default_directory: DownloadHelpers::PATH.to_s)
      browser_options.add_preference(:browser, set_download_behavior: { behavior: 'allow' })

      Capybara::Selenium::Driver.new(app, browser: :chrome, options: browser_options)
    end

    driven_by :selenium_chrome_headless_download

    create(:facilitator, user: user)
    create(:downloadable_asset, owner: resource)
    clear_downloads
  end

  after do
    clear_downloads
  end

  describe "when user is logged in" do
    before { sign_in user }

    context "from the dashboard" do
      it "downloads the resource" do
        visit root_path

        find("a[href='/resources/#{resource.id}/download']").click

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end

    context "from the resources index page" do
      it "downloads the resource" do
        visit resources_path

        find("a[href='/resources/#{resource.id}/download']").click

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end

    context "when visiting download path directly" do
      it "downloads the resource" do
        visit "/resources/#{resource.id}/download"

        wait_for_download
        expect(downloads.length).to eq(1)
        expect(download).to match(/.*\.pdf/)
      end
    end
  end
end
