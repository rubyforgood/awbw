class WorkshopVariationIdea < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :workshop
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :workshop_variations

  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :organization_id, presence: true
  validates :workshop_id, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # Scopes
  scope :workshop_id, ->(workshop_id) { where(workshop_id: workshop_id) if workshop_id.present? }

  def title
    name
  end
end
