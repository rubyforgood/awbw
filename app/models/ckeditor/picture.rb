class Ckeditor::Picture < ApplicationRecord # Ckeditor::Asset
  self.table_name = "ckeditor_assets"

  has_one_attached :data # TODO - convert to GalleryImage ???

  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png"].freeze
  validates :data, size: {less_than: 2.megabytes}, content_type: ACCEPTED_CONTENT_TYPES, attached: true

  def url_content
    url(:content)
  end

  def url(param)
    return super if actual_url.nil?

    if param == :content
      return actual_url
    else
      actual_url.gsub("/original", "/thumb")
    end
  end
end
