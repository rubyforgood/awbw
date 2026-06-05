class Tutorial < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, RichTextSearchable

  has_rich_text :rhino_body

  belongs_to :author, class_name: "User", optional: true
  belongs_to :created_by, class_name: "User", optional: true

  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  validates :title, presence: true, uniqueness: { case_sensitive: false }

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :gallery_assets, reject_if: :all_blank, allow_destroy: true

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes all: [ :title, :body ]
    options :all, type: :text, default: true, default_operator: :or

    scope { join_rich_texts }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  scope :body, ->(body) {
    left_joins(:rich_text_rhino_body)
      .where("tutorials.body LIKE :q OR action_text_rich_texts.body LIKE :q", q: "%#{body}%")
  }
  scope :title, ->(title) { where("title like ?", "%#{ title }%") }
  scope :tutorial_name, ->(tutorial_name) { title(tutorial_name) }
  scope :with_sector_ids, ->(sector_hash) {
    ids = sector_hash.values.reject(&:blank?).map(&:to_i)
    return all if ids.empty?
    joins(:sectorable_items)
      .where(sectorable_items: { sectorable_type: "Tutorial", sector_id: ids })
      .distinct
  }

  scope :with_category_ids, ->(category_hash) {
    ids = category_hash.values.reject(&:blank?).map(&:to_i)
    return all if ids.empty?
    joins(:categorizable_items)
      .where(categorizable_items: { categorizable_type: "Tutorial", category_id: ids })
      .distinct
  }

  scope :title_or_body, ->(term) {
    scope = left_joins(:rich_text_rhino_body)
    term.split.each do |word|
      pattern = "%#{word}%"
      scope = scope.where("tutorials.title LIKE :q OR tutorials.body LIKE :q OR action_text_rich_texts.body LIKE :q", q: pattern)
    end
    scope
  }

  def self.search_by_params(params)
    resources = is_a?(ActiveRecord::Relation) ? self : all
    resources = resources.title_or_body(params[:search]) if params[:search].present?
    resources = resources.title(params[:title]) if params[:title].present?
    resources = resources.body(params[:body]) if params[:body].present?
    if visibility_params_present?(params)
      resources = apply_visibility_filters(resources, params)
    elsif params[:published].present?
      resources = resources.published(params[:published])
    end
    resources = resources.with_sector_ids(params[:sectors]) if params[:sectors].present?
    resources = resources.with_category_ids(params[:categories]) if params[:categories].present?
    resources = resources.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    resources = resources.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    resources
  end
end
