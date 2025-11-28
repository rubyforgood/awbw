class CommunityNews < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :author, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Validations
  validates :author_id, presence: true
  validates :title, presence: true
  validates :body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  scope :featured, -> { where(featured: true) }
  scope :published, -> { where(published: true) }
end
