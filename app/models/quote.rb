class Quote < ApplicationRecord
  include Publishable, TagFilterable, Trendable, WindowsTypeFilterable

  belongs_to :workshop, optional: true
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

  validates :quote, presence: true, unless: -> { quote.blank? }
  validates :age, length: { maximum: 255 }
  validates :speaker_name, length: { maximum: 255 }

  # Preserve the untouched submission the first time we store a body, so later
  # edits to `quote` (the published/displayed text) never lose the original.
  before_save :capture_original_quote

  scope :standout, ->(flag = nil) do
    value = flag.nil? || flag == "" ? true : ActiveModel::Type::Boolean.new.cast(flag)
    where(standout: value)
  end

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :quote, :original_quote
  end

  def self.search_by_params(params)
    quotes = is_a?(ActiveRecord::Relation) ? self : all
    quotes = quotes.search(params[:query]) if params[:query].present? # SearchCop incl title, author, text
    quotes = quotes.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    quotes = quotes.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    quotes = quotes.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    quotes = quotes.published(params[:published]) if params[:published].present?
    quotes = quotes.featured(params[:featured]) if params[:featured].present?
    quotes = quotes.standout(params[:standout]) if params[:standout].present?
    quotes
  end

  def speaker
    speaker_name.nil? || speaker_name.empty?  ? "Participant" : speaker_name
  end

  def name
    quote.truncate(30)
  end

  private

  def capture_original_quote
    self.original_quote = quote if original_quote.blank? && quote.present?
  end
end
