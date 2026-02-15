class StoryIdea < ApplicationRecord
  PUBLISH_PREFERENCES = [
    "I would like my full name published with the story",
    "I would like only my first name published",
    "I do not want my name published with my story"
  ]

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :organization
  belongs_to :windows_type
  belongs_to :workshop, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :stories
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Validations
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :organization_id, presence: true
  validates :windows_type_id, presence: true
  validates :body, presence: true
  validates :permission_given, presence: true
  validates :publish_preferences, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :categorizable_items, allow_destroy: true, reject_if: :all_blank

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
    organization.name
  end

  def organization_locality
    organization&.organization_locality
  end

  def organization_description
    organization&.organization_description
  end
end
