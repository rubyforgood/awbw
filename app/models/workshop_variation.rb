class WorkshopVariation < ApplicationRecord
  include AuthorCreditable
  include Publishable, Trendable, RichTextSearchable
  include SearchCop
  search_scope :search do
    attributes all: [ :name ]
    options :all, type: :text, default: true, default_operator: :or

    scope { join_rich_texts }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    if params[:query].present?
      by_text = results.search(params[:query]).select("workshop_variations.id")
      by_person = results.by_credited_person_name(params[:query]).select("workshop_variations.id")
      results = results.where(id: by_text).or(results.where(id: by_person))
    end
    results = results.authored_by(params[:author_id])
    results
  end

  has_rich_text :rhino_body

  belongs_to :workshop, optional: true
  belongs_to :organization, optional: true
  belongs_to :windows_type, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :author, class_name: "Person", optional: true
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
  validates :windows_type_id, presence: true
  validates :rhino_body, presence: true

  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # Scopes
  # See Publishable, Trendable

  def description
    rhino_body.to_plain_text
  end

  # Unattributed workshop variations are credited to the generic facilitator.
  def missing_author_label
    "AWBW Facilitator"
  end

  def title
    name
  end

  def attach_assets_from_idea!
    return unless workshop_variation_idea

    has_primary = primary_asset&.file&.attached?
    workshop_variation_idea.assets.order(:id).each do |asset|
      new_type = if !has_primary && asset.type == "GalleryAsset"
        has_primary = true
        "PrimaryAsset"
      else
        "GalleryAsset"
      end
      new_asset = assets.build(type: new_type)
      new_asset.file.attach(asset.file.blob)
    end

    save!
  end
end
