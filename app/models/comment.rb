class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  validates :body, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
end
