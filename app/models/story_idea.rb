class StoryIdea < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :project
  belongs_to :windows_type
  belongs_to :workshop, optional: true
  has_many :stories
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Validations
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :project_id, presence: true
  validates :windows_type_id, presence: true
  validates :workshop_id, presence: true
  validates :body, presence: true
  validates :permission_given, presence: true
  validates :publish_preferences, presence: true

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  def name
    "StoryIdea ##{id}"
  end

  def full_name
    "#{created_at.strftime("%Y-%m-%d")} #{author_credit}: #{workshop_title}"
  end

  def workshop_title
    workshop&.title ||  "[#{external_workshop_title}]"
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
    project&.organization_locality
  end

  def organization_description
    project&.organization_description
  end
end
