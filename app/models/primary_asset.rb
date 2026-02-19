class PrimaryAsset < Asset
  ACCEPTED_CONTENT_TYPES = [
    "image/jpeg",
    "image/png",
    "image/webp",
    "image/heic",
    "image/heif"
  ].freeze
end
