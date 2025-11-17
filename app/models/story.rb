class Story < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  belongs_to :story_idea, optional: true
  belongs_to :project
  belongs_to :windows_type
  belongs_to :workshop
  belongs_to :spotlighted_facilitator, class_name: "Facilitator",
             foreign_key: "spotlighted_facilitator_id", optional: true
  validates :windows_type_id, presence: true
  validates :project_id, presence: true
  validates :workshop_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :body, presence: true

  # Images
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png" ].freeze
  has_one_attached :main_image
  has_many_attached :images
  validates :main_image, content_type: ACCEPTED_CONTENT_TYPES
  validates :images, content_type: ACCEPTED_CONTENT_TYPES

  def name
    title
  end

  def organization_name
    project.name
  end

  def organization_locality
    project.addresses.active.first&.locality
  end

  def organization_description
    "#{organization_name}, #{organization_locality}"
  end
end
