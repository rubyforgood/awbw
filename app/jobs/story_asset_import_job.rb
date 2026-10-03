class StoryAssetImportJob < ApplicationJob
  queue_as :default

  # Downloads a story's images and attaches them to the record. The image_urls come
  # from the sheet's "image_urls" column in order: the first is the featured image
  # (PrimaryAsset), the rest become GalleryAssets. `titles` is the parallel list
  # from "image_alt_titles" — each image takes the title at its position. A bad URL
  # or rejected file is logged and skipped so one broken image doesn't take down
  # the rest.
  def perform(record, image_urls, titles: [])
    pairs = Array(image_urls).each_with_index.map { |url, i| [ url, Array(titles)[i] ] }
    pairs.reject { |url, _| url.blank? }.each_with_index do |(url, title), index|
      import(record, url, index.zero? ? "PrimaryAsset" : "GalleryAsset", title)
    end
  end

  private

  def import(record, url, type, title)
    AssetUrlImporter.new(url: url, owner: record, type: type, title: title).call
  rescue AssetUrlImporter::Error, ActiveRecord::RecordInvalid => e
    Rails.logger.warn("[StoryAssetImportJob] #{record.class}##{record.id} #{url}: #{e.message}")
  end
end
