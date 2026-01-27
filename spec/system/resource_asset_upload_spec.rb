# spec/system/resource_asset_upload_spec.rb
require "rails_helper"

RSpec.describe "Resource asset upload", type: :system do
  let(:super_user) { create(:user, super_user: true) }

  before do
    sign_in super_user
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
    when "DownloadableAsset", "Downloadable asset"
      "Downloadable_asset_"
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
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Primary asset")
    end

    it "uploads a downloadable asset" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Downloadable asset")
    end

    it "uploads a gallery asset" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Gallery asset")
    end

    it "allows deleting a primary asset and re-uploading a new one" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      delete_asset(asset_type: "Primary asset")

      expect(page).not_to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "shows an error when trying to upload a second primary asset" do
      visit new_resource_path

      # Upload the first Primary asset
      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "shows an error when trying to upload a second downloadable asset" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='downloadable_asset_']")

      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "allows uploading Primary, Downloadable and Gallery assets" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='downloadable_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "associates uploaded assets with the resource on submit" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      title = SecureRandom.uuid

      within("#new_resource") do
        fill_in "Title", with: title
        select "Handout", from: "Kind"
        click_button "Submit"
      end

      sleep 0.2
      resource = Resource.find_by!(title: title)

      expect(resource.assets.count).to eq(1)
      expect(resource.assets.first.type).to eq("PrimaryAsset")
    end

    it "does not associate deleted assets with the resource on submit" do
      visit new_resource_path

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      delete_asset(asset_type: "Primary asset")

      title = SecureRandom.uuid

      within("#new_resource") do
        fill_in "Title", with: title
        select "Handout", from: "Kind"
        click_button "Submit"
      end

      sleep 0.2
      resource = Resource.find_by!(title: title)

      expect(resource.assets.count).to eq(0)
    end
  end

  context "edit" do
    it "uploads a primary asset" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")
    end

    it "uploads a downloadable asset" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='downloadable_asset_']")
    end

    it "uploads a gallery asset" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "allows deleting a primary asset and re-uploading a new one" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")

      delete_asset(asset_type: "Primary asset")

      expect(page).not_to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "shows an error when trying to upload a second primary asset" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      # Upload the first Primary asset
      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='primary_asset_']")
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "shows an error when trying to upload a second downloadable asset" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")

      expect(page).to have_selector("div[id^='downloadable_asset_']")
      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")


      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end

    it "allows uploading Primary, Downloadable and Gallery assets" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      # Upload the first Downloadable asset
      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='downloadable_asset_']")

      upload_asset(type: "Gallery asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='gallery_asset_']")
    end

    it "associates uploaded assets with the resource on submit" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")

      title = SecureRandom.uuid

      # Submit the Resource form
      within("form[id^='edit_resource_']") do
              fill_in "Title", with: title
              select "Handout", from: "Kind"
              click_button "Submit"
            end

      sleep 0.2
      resource = Resource.find_by!(title: title)

      # Assert the asset association
      expect(resource.assets.count).to eq(1)
      expect(resource.assets.first.type).to eq("PrimaryAsset")
    end

    it "does not associate deleted assets with the resource on submit" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)

      find("#assets-button").click
      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")


      delete_asset(asset_type: "Primary asset")

      title = SecureRandom.uuid

      within("form[id^='edit_resource_']") do
        fill_in "Title", with: title
        select "Handout", from: "Kind"
        click_button "Submit"
      end

      sleep 0.2
      resource = Resource.find_by!(title: title)

      expect(resource.assets.count).to eq(0)
    end

    it "updates asset type" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)
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

    it "shows an error when change asset type with invalid file type" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)
      find("#assets-button").click

      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.pdf")
      expect(page).to have_selector("div[id^='downloadable_asset_']")


      within("div[id^='downloadable_asset_']") do
        select "Primary asset", from: "library_asset_type"
      end

      expect(page).to have_content("File type is not allowed for Primary asset")
    end

    it "shows an error when changing an uploaded asset to a duplicate type on edit" do
      resource = create(:resource, title: SecureRandom.uuid, kind: "Handout")

      visit edit_resource_path(resource)
      find("#assets-button").click

      upload_asset(type: "Primary asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='primary_asset_']")

      upload_asset(type: "Downloadable asset", file: "spec/fixtures/files/sample.png")
      expect(page).to have_selector("div[id^='downloadable_asset_']")

      within("div[id^='primary_asset_']") do
        select "Downloadable asset", from: "library_asset_type"
      end

      expect(page).to have_content("Only one Primary or Downloadable asset allowed.")
    end
  end
end
