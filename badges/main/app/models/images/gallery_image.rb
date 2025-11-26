module Images
  class GalleryImage < Image
    ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif"].freeze

    validates :file, content_type: ACCEPTED_CONTENT_TYPES
  end
end
