class WorkshopVariation < ApplicationRecord
  belongs_to :workshop
  belongs_to :created_by, class_name: 'User', optional: true
  # Image associations
  has_many :images, as: :owner, dependent: :destroy
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }

  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  scope :active, -> { where(inactive: false) }

  def description
    code # TODO - rename this field
  end

  def title
    name
  end
end
