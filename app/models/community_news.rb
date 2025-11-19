class CommunityNews < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :windows_type, optional: true

  belongs_to :author, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :author_id, presence: true
  validates :title, presence: true
  validates :body, presence: true

  scope :featured, -> { where(featured: true) }
  scope :published, -> { where(published: true) }
end
