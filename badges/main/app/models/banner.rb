class Banner < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :content, presence: true

  scope :published, -> { where(show: true) }

  def name
    content.truncate(50)
  end
end
