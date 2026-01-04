class WorkshopVariation < ApplicationRecord
  include Trendable, ViewCountable

  belongs_to :workshop
  belongs_to :created_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  # Asset associations
  has_many :images, as: :owner, dependent: :destroy
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }

  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  scope :active, -> { where(inactive: false) }
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :published, -> { all }

  delegate :windows_type, to: :workshop

  def description
    code # TODO - rename this field
  end

  def title
    name
  end
end
