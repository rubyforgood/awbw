class Story < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :windows_type
  belongs_to :project, optional: true
  belongs_to :spotlighted_facilitator, class_name: "Facilitator",
             foreign_key: "spotlighted_facilitator_id", optional: true
  belongs_to :story_idea, optional: true
  belongs_to :workshop, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Validations
  validates :windows_type_id, presence: true
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  # Scopes
  scope :featured, -> { where(featured: true) }
  scope :published, -> { where(published: true) }

  def name
    title
  end

  def organization_name
    project&.name
  end

  def organization_locality
    project&.organization_locality
  end

  def organization_description
    project&.organization_description
  end
end
