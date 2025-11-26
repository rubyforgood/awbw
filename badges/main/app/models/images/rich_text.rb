module Images
  class RichText < Image
    ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif", "application/pdf", "application/msword"].freeze

    validates :file, content_type: ACCEPTED_CONTENT_TYPES
  end
end
