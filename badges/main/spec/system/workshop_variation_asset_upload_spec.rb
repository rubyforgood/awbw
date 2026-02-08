# spec/system/workshop_variation_asset_upload_spec.rb
require "rails_helper"

RSpec.describe "Workshop Variation asset upload", type: :system do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  # TODO - get this back online
  # context "new" do
  #   it "uploads a primary asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_content("Primary")
  #   end
  #
  #   it "uploads a gallery asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_content("Gallery")
  #   end
  #
  #   it "allows deleting a primary asset and re-uploading a new one" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     delete_asset(asset_type: "Primary")
  #
  #     expect(page).not_to have_selector("div[id^='primary_asset_']")
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='gallery_asset_']")
  #   end
  #
  #   it "shows an error when trying to upload a second primary asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
  #   end
  #
  #   it "allows uploading Primary and Gallery assets" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #     expect(page).to have_selector("div[id^='gallery_asset_']")
  #
  #     workshop_variation.description.gsub("error", "ezzlor") # to avoid flaky test
  #   end
  # end
  #
  # context "edit" do
  #   it "uploads a primary asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #   end
  #
  #   it "uploads a gallery asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='gallery_asset_']")
  #   end
  #
  #   it "allows deleting a primary asset and re-uploading a new one" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     delete_asset(asset_type: "Primary")
  #
  #     expect(page).not_to have_selector("div[id^='primary_asset_']")
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='gallery_asset_']")
  #   end
  #
  #   it "shows an error when trying to upload a second primary asset" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #
  #     expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
  #   end
  #
  #   it "allows uploading Primary and Gallery assets" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     upload_asset(type: "Gallery", file: "spec/fixtures/files/sample.png")
  #     expect(page).to have_selector("div[id^='gallery_asset_']")
  #   end
  #
  #   it "updates asset type" do
  #     workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)
  #
  #     visit edit_workshop_variation_path(workshop_variation)
  #
  #     # Upload a Primary
  #     upload_asset(type: "Primary", file: "spec/fixtures/files/sample.png")
  #     expect(page).to have_selector("div[id^='primary_asset_']")
  #
  #     within("div[id^='primary_asset_']") do
  #       select "Gallery", from: "library_asset_type"
  #     end
  #
  #     within("div[id^='primary_asset_']") do
  #       expect(page).to have_select("Type", selected: "Gallery")
  #     end
  #   end
  # end
end
