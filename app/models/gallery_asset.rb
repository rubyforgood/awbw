class GalleryAsset < Asset
  ACCEPTED_CONTENT_TYPES = [ "image/jpeg", "image/png", "image/gif", "application/pdf" ].freeze

  validates :file, content_type: ACCEPTED_CONTENT_TYPES
end
