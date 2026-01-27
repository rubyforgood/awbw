# spec/system/workshop_variation_asset_upload_spec.rb
require "rails_helper"

RSpec.describe "Workshop Variation asset upload", type: :system do
  let(:admin) { create(:user, super_user: true) }

  before do
    sign_in admin
  end

  def upload_asset(type:, file:)
    within("#asset_upload") do
      select type, from: "library_asset_type"
    end

    attach_file(
      "asset_file_input",
      Rails.root.join(file)
    )

    # Submit the asset form
    click_button "Upload Asset"
  end

  def delete_asset(asset_type:)
    div_prefix = case asset_type
    when "PrimaryAsset", "Primary asset"
      "primary_asset_"
    when "GalleryAsset", "Gallery asset"
      "gallery_asset_"
    else
      raise "Unknown asset type: #{asset_type}"
    end

    # Find the first matching asset container
    asset_container = find("div[id^='#{div_prefix}']")

    accept_confirm("Delete this asset?") do
      asset_container.find("form.button_to button[type='submit']", visible: :all).click
    end

    expect(page).not_to have_selector("div[id^='#{div_prefix}']")
  end

  context "new" do
    it "uploads a primary asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Primary asset")
    end

    it "uploads a gallery asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Gallery asset")
    end

    it "allows deleting a primary asset and re-uploading a new one" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      delete_asset(asset_type: "Primary asset")

      expect(page).not_to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "shows an error when trying to upload a second primary asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "allows uploading Primary and Gallery assets" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='gallery_asset_']")

      workshop_variation.description.gsub("error", "ezzlor") # to avoid flaky test
    end
  end

  context "edit" do
    it "uploads a primary asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")
    end

    it "uploads a gallery asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "allows deleting a primary asset and re-uploading a new one" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      delete_asset(asset_type: "Primary asset")

      expect(page).not_to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "shows an error when trying to upload a second primary asset" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "allows uploading Primary and Gallery assets" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "updates asset type" do
      workshop_variation = create(:workshop_variation, name: SecureRandom.uuid)

      visit edit_workshop_variation_path(workshop_variation)
      find("#assets-button").click

      # Upload a Primary asset
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      within("div[id^='primary_asset_']") do
        select "Gallery asset", from: "library_asset_type"
      end

      within("div[id^='primary_asset_']") do
        expect(find("select#library_asset_type").value).to eq("GalleryAsset")
      end
    end
  end
end
