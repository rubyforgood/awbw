class Image < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true

  has_attached_file :file,
                    styles: { medium: '300x300>', thumb: '100x100>' },
                    default_url:
                      ActionController::Base.helpers.asset_path(
                        'workshop_default.png'
                      )
  validates_attachment :file, content_type: { content_type:  ["image/jpg", "image/jpeg", "image/png", "image/gif"] }
end
