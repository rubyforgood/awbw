class Banner < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :content, presence: true
end
