module AssetUploadHelpers
  def delete_asset(asset_type:)
    div_prefix =
      case asset_type
      when "PrimaryAsset", "Primary"
        "primary_asset_"
      when "DownloadableAsset", "Downloadable"
        "Downloadable_asset_"
      when "GalleryAsset", "Gallery"
        "gallery_asset_"
      else
        raise "Unknown asset type: #{asset_type}"
      end

    within("turbo-frame#assets") do
      asset_container = find("div[id^='#{div_prefix}']")

      accept_confirm("Delete this asset?") do
        asset_container
          .find("form.button_to button[type='submit']", visible: :all)
          .click
      end
    end

    expect(page).to have_no_selector("div[id^='#{div_prefix}']")
    expect(page).to have_selector("#asset_upload_form")
  end

  def upload_asset(type:, file:)
    expect(page).to have_selector("turbo-frame#assets")

    within("turbo-frame#assets", wait: 5) do
      expect(page).to have_selector("#asset_upload_form")

      select type, from: "asset_upload_type"
      attach_file "asset_file_input", Rails.root.join(file)
      click_button "Upload Asset"
    end
  end
end
