class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true

  validates :body, presence: true

  default_scope { order(created_at: :desc) }
end
