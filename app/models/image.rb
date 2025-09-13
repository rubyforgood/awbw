class Image < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true

  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png", "image/gif"].freeze

  if ENV["ACTIVE_STORAGE"].present?
    has_one_attached :file
    validates :file, content_type: ACCEPTED_CONTENT_TYPES
  else
    has_attached_file :file,
      styles: {medium: "300x300>", thumb: "100x100>"},
      default_url:
        ActionController::Base.helpers.asset_path(
          "workshop_default.png"
        )
    validates_attachment :file, content_type: {content_type: ACCEPTED_CONTENT_TYPES}
  end
end
