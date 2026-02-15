class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  validates :body, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
end
