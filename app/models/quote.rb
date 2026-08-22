class Quote < ApplicationRecord
  include AuthorCreditable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable

  belongs_to :workshop, optional: true
  belongs_to :author, class_name: "Person", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :quotable_item_quotes, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  validates :body, presence: true, unless: -> { body.blank? }
  validates :age, length: { maximum: 255 }
  validates :speaker_name, length: { maximum: 255 }

  # Preserve the untouched submission the first time we store a body, so later
  # edits to `body` (the published/displayed text) never lose the original.
  before_save :capture_original_body

  scope :standout, ->(flag = nil) do
    value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
    where(standout: value)
  end

  # Search Cop
  include SearchCop
  search_scope :search do
    # Author-name search — the linked person or the legacy speaker_name column —
    # goes through `by_credited_person_name` (honors the credit preference), OR-ed
    # into these full-text results in `search_by_params`.
    attributes :body, :original_body
  end

  # The legacy free-text speaker name folds into credited-name search and sort.
  # Most quotes come from workshop participants who are not people in the DB, so
  # this column is the credit for the majority of rows.
  def self.legacy_author_name_columns
    [ "quotes.speaker_name" ]
  end

  def legacy_author_name_text
    speaker_name
  end

  def self.search_by_params(params)
    quotes = is_a?(ActiveRecord::Relation) ? self : all
    if params[:query].present?
      # SearchCop covers body + original submission; OR in the credited author name
      # — linked person and legacy speaker_name — via id subqueries (isolated joins).
      by_text = quotes.search(params[:query]).select("quotes.id")
      by_person = quotes.by_credited_person_name(params[:query]).select("quotes.id")
      quotes = quotes.where(id: by_text).or(quotes.where(id: by_person))
    end
    quotes = quotes.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    quotes = quotes.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    quotes = quotes.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    quotes = quotes.published(params[:published]) if params[:published].present?
    quotes = quotes.featured(params[:featured]) if params[:featured].present?
    quotes = quotes.standout(params[:standout]) if params[:standout].present?
    quotes = quotes.authored_by(params[:author_id])
    quotes
  end

  # Prefer the linked person, falling back to the legacy free-text speaker name.
  def speaker
    author&.name.presence || speaker_name.presence || "Participant"
  end

  def name
    body.truncate(30)
  end

  private

  def capture_original_body
    self.original_body = body if original_body.blank? && body.present?
  end
end
