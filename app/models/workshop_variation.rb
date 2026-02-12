class WorkshopVariation < ApplicationRecord
  include Publishable, Trendable

  belongs_to :workshop
  belongs_to :organization, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :workshop_variation_idea, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :workshop_id, case_sensitive: false }
  validates :body, presence: true

  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  delegate :windows_type, to: :workshop

  # Scopes
  # See Publishable, Trendable
  scope :publicly_visible, -> { joins(:workshop).where("workshops.publicly_visible = ?", true)
                                                .published } # overrides Publishable

  def description
    body
  end

  def title
    name
  end

  def attach_assets_from_idea!
    return unless workshop_variation_idea

    workshop_variation_idea.assets.find_each do |asset|
      new_asset = assets.build(type: asset.type)
      new_asset.file.attach(asset.file.blob)
    end

    save!
  end
end
