class Banner < ApplicationRecord
  include Publishable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :content, presence: true

  # Scopes
  # See Publishable

  def name
    content.truncate(50)
  end
end
