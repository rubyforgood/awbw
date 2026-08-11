class StoryAssetImportJob < ApplicationJob
  queue_as :default

  # Downloads a WordPress story's images and attaches them to the record. The
  # image_urls come from the export's "Image URL" column in order: the first is
  # the featured image (PrimaryAsset), the rest become GalleryAssets. `title` is
  # the alt text. A bad URL or rejected file is logged and skipped so one broken
  # image doesn't take down the rest.
  def perform(record, image_urls, title: nil)
    featured, *gallery = Array(image_urls).compact_blank
    import(record, featured, "PrimaryAsset", title) if featured.present?
    gallery.each { |url| import(record, url, "GalleryAsset", title) }
  end

  private

  def import(record, url, type, title)
    AssetUrlImporter.new(url: url, owner: record, type: type, title: title).call
  rescue AssetUrlImporter::Error, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[StoryAssetImportJob] #{record.class}##{record.id} #{url}: #{e.message}")
  end
end
