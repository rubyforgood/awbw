class StoryIdea < ApplicationRecord
  include AuthorCreditable
  # Public submission: the submitter must choose how they're credited.
  require_author_credit_preference
  include SearchCop
  search_scope :search do
    attributes :title, :body
  end

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:query]) if params[:query].present?
    results = results.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    results = results.created_by_person(params[:created_by_person_id]) if params[:created_by_person_id].present?
    results
  end

  has_rich_text :rhino_body

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
  validates :permission_given, presence: true
  validates :rhino_body, presence: true

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  def name
    "StoryIdea ##{id}"
  end

  def full_name
    base = "#{created_at.strftime("%Y-%m-%d")} #{author_credit}"
    title = workshop_title
    title.present? ? "#{base}: #{title}" : base
  end

  def workshop_title
    [ workshop&.title, external_workshop_title.presence ].compact_blank.presence&.join(" / ")
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
