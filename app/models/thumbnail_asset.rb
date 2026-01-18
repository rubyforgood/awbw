class ThumbnailAsset < Asset
  ACCEPTED_CONTENT_TYPES = [ "image/jpeg", "image/png" ].freeze

  validates :file, content_type: ACCEPTED_CONTENT_TYPES
end
