class StoryIdea < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  belongs_to :project
  belongs_to :windows_type
  belongs_to :workshop
  has_many :stories

  validates :windows_type_id, presence: true
  validates :project_id, presence: true
  validates :workshop_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :body, presence: true
  validates :permission_given, presence: true
  validates :publish_preferences, presence: true

  # Images
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png" ].freeze
  has_one_attached :main_image
  has_many_attached :images
  validates :main_image, content_type: ACCEPTED_CONTENT_TYPES
  validates :images, content_type: ACCEPTED_CONTENT_TYPES

  def name
    title
  end

  def full_name
    "#{created_at.strftime("%Y-%m-%d")} #{author_credit}: #{title}"
  end

  def author_credit
    case publish_preferences
    when "I would like my full name published with the story"
      created_by.full_name
    when "I would like only my first name published"
      created_by.first_name
    else # "I do not want my name published with my story"
      "Anonymous"
    end
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
