class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Required for new comments only — existing comments (some legacy ones may have
  # blank bodies) must stay savable, so this is intentionally not a blanket
  # validation. The UI enforces it client-side via the field-required controller.
  validates :body, presence: true, unless: :persisted?

  scope :newest_first, -> { order(created_at: :desc) }
  scope :flagged, -> { where(flagged: true) }
end
