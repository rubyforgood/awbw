class Workshop < ApplicationRecord
  include TagFilterable, Trendable, WindowsTypeFilterable, RichTextSearchable
  include Rails.application.routes.url_helpers
  include ActionText::Attachable
  include ActiveModel::Dirty

  belongs_to :windows_type, optional: true
  belongs_to :user, optional: true
  belongs_to :workshop_idea, optional: true

  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :quotable_item_quotes, as: :quotable, dependent: :destroy
  has_many :associated_resources, class_name: "Resource", foreign_key: "workshop_id", dependent: :restrict_with_error
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  has_many :workshop_logs, dependent: :destroy, as: :owner
  has_many :workshop_resources, dependent: :destroy
  has_many :workshop_series_children, # When this workshop is the parent in a series
           -> { order(:position) },
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_parent_id",
           dependent: :destroy
  has_many :workshop_series_parents, # When this workshop is the child in a series
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_child_id",
           dependent: :destroy
  has_many :workshop_variations, dependent: :restrict_with_error

  # has_many through
  has_many :age_ranges, -> { joins(:category_type).where(category_types: { name: "AgeRange" }) },
           through: :categorizable_items, source: :category # needs to be after has_many :categorizable_items
  has_many :categories, through: :categorizable_items
  has_many :category_types, through: :categories
  has_many :quotes, through: :quotable_item_quotes
  has_many :resources, through: :workshop_resources, source: :resource
  has_many :sectors, through: :sectorable_items

  # Images
  has_one_attached :thumbnail # old paperclip -- TODO convert these to AvatarImage records
  has_one_attached :header # old paperclip -- TODO convert these to MainImage records
  has_many :attachments, as: :owner, dependent: :destroy # old paperclip -- TODO convert these to GalleryImage records
  has_many :images, as: :owner, dependent: :destroy # old paperclip -- TODO convert these to GalleryImage records
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :rich_text_assets, -> { where(type: "RichTextAsset") },
         as: :owner, class_name: "RichTextAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  has_many :action_text_mentions,
           as: :mentionable,
           dependent: :destroy

  has_many :action_text_rich_texts,
           through: :action_text_mentions

  # Rhino Editor Fields
  has_rich_text :rhino_objective
  has_rich_text :rhino_materials
  has_rich_text :rhino_optional_materials
  has_rich_text :rhino_setup
  has_rich_text :rhino_introduction
  has_rich_text :rhino_opening_circle
  has_rich_text :rhino_demonstration
  has_rich_text :rhino_warm_up
  has_rich_text :rhino_visualization
  has_rich_text :rhino_creation
  has_rich_text :rhino_closing
  has_rich_text :rhino_notes
  has_rich_text :rhino_tips
  has_rich_text :rhino_misc1
  has_rich_text :rhino_misc2
  has_rich_text :rhino_extra_field

  has_rich_text :rhino_objective_spanish
  has_rich_text :rhino_materials_spanish
  has_rich_text :rhino_optional_materials_spanish
  has_rich_text :rhino_age_range_spanish
  has_rich_text :rhino_setup_spanish
  has_rich_text :rhino_introduction_spanish
  has_rich_text :rhino_opening_circle_spanish
  has_rich_text :rhino_demonstration_spanish
  has_rich_text :rhino_warm_up_spanish
  has_rich_text :rhino_visualization_spanish
  has_rich_text :rhino_creation_spanish
  has_rich_text :rhino_closing_spanish
  has_rich_text :rhino_notes_spanish
  has_rich_text :rhino_tips_spanish
  has_rich_text :rhino_misc1_spanish
  has_rich_text :rhino_misc2_spanish
  has_rich_text :rhino_extra_field_spanish

  # Temporary storage for association IDs during creation
  attr_accessor :pending_sector_ids, :pending_category_ids

  # Callbacks
  before_save :set_time_frame
  before_save :invalidate_featured_cache_if_changed
  after_save :assign_pending_associations

  # Validations
  validates_presence_of :title
  # validates_presence_of :month, :year, if: Proc.new { |workshop| workshop.legacy }
  validates_length_of :age_range, maximum: 16
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  # Nested attributes
  accepts_nested_attributes_for :quotes, reject_if: proc { |object| object["quote"].nil? }
  accepts_nested_attributes_for :workshop_logs, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :workshop_series_children,
                                reject_if: proc { |attributes| attributes["workshop_child_id"].blank? },
                                allow_destroy: true
  accepts_nested_attributes_for :workshop_variations, reject_if: proc { |object| object.nil? }


  # Scopes
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }
  scope :created_by_id, ->(created_by_id) { where(user_id: created_by_id) }
  scope :featured, -> { where(featured: true) }
  scope :visitor_featured, -> { where(visitor_featured: true) }
  scope :legacy, -> { where(legacy: true) }
  scope :published, ->(published = nil) { published.to_s.present? ?
           where(inactive: !published) : where(inactive: false) }
  scope :title, ->(title) { where("workshops.title like ?", "%#{ title }%") }
  scope :windows_type_ids, ->(windows_type_ids) { where(windows_type_id: windows_type_ids) }
  scope :order_by_date, ->(sort_order = "asc") {
    order(Arel.sql(<<~SQL.squish))
    COALESCE(
      STR_TO_DATE(
        CONCAT(workshops.year, '-', LPAD(workshops.month, 2, '0'), '-01'),
        '%Y-%m-%d'
      ),
      DATE(workshops.created_at)
    ) #{sort_order == "asc" ? "ASC" : "DESC"}
    SQL
  }
  scope :with_bookmarks_count, -> {
    left_joins(:bookmarks)
      .select("workshops.*, COUNT(bookmarks.id) AS bookmarks_count")
      .group("workshops.id")
  }
  scope :featured_or_visitor_featured, -> {
    where("(featured = ? OR visitor_featured = ?) AND inactive = ?", true, true, false)
  }

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes all: [ :title, :full_name ] # no spanish alternatives
    options :all, type: :text, default: true, default_operator: :or

    attributes :title, type: :text

    scope { join_rich_texts }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  def self.grouped_by_sector
    Sector.all.map { |sector| Hash[sector.name, sector.workshops] }.flatten
  end

  def author_name
    return unless user
    user.full_name
  end

  def date
    if month.present? && year.present?
      Date.new(year.to_i, month.to_i).strftime("%B %Y")
    else
      created_at.strftime("%B %Y")
    end
  end

  def name
    title
  end

  def workshop_log_fields
    if form_builder
      form_builder.forms[0].form_fields.where("position is not null and status = 1")
        .order(position: :desc).all
    else
      []
    end
  end

  def form_builder
    FormBuilder
      .workshop_logs
      .find_by(windows_type: windows_type)
  end

  def windows_type_name
    windows_type.name if windows_type
  end

  def related_workshops
    []
  end

  def default_image_url
    ActionController::Base.helpers.asset_path(
      "workshop_default.jpg"
    )
  end

  def rating
    return 0 unless log_count > 0
    workshop_logs.sum(:rating) / log_count
  end

  def log_count
    workshop_logs.size
  end

  def sector_hashtags
    sectors.map do |sector|
      "\#{sector.name.split(" ")[0].downcase}"
    end.join(",")
  end

  def type_name
    "#{title} #{"(#{windows_type.short_name}) " if windows_type}##{id}"
  end

  def communal_label(report)
    "Workshop Title: #{title} - Workshop Date: #{report.date ? report.date.strftime("%m/%d/%y") : "[ EMPTY ]"}"
  end

  def published_sectors
    sectorable_items.published.map { |item| item.sector }
  end

  def time_frame_total
    total_minutes = time_intro.to_i + time_demonstration.to_i +
      time_opening.to_i + time_opening_circle.to_i + time_warm_up.to_i +
      time_creation.to_i + time_closing.to_i

    return "00:00" if total_minutes == 0

    # Custom rounding: minimum 15 min, then nearest 15
    total_minutes = [ 15, (total_minutes / 15.0).round * 15 ].max

    hours, minutes = total_minutes.divmod(60)

    if hours.positive?
      "#{hours}:#{format('%02d', minutes)} hours"
    else
      "#{minutes} min"
    end
  end

  def set_time_frame
    self.timeframe = time_frame_total
  end

  # Override sector_ids= to defer association assignment until after save
  def sector_ids=(ids)
    if new_record?
      @pending_sector_ids = ids
    else
      super
    end
  end

  # Override category_ids= to defer association assignment until after save
  def category_ids=(ids)
    if new_record?
      @pending_category_ids = ids
    else
      super
    end
  end

  ## ActionText:Attachable
  def attachable_content_type
    "application/vnd.active_record.workshop"
  end

  def invalidate_featured_cache_if_changed
    if featured_or_visitor_featured_changed?
      Rails.cache.delete("featured_and_visitor_featured_workshop_ids")
    end
  end

  def featured_or_visitor_featured_changed?
    featured_changed? || visitor_featured_changed? || inactive_changed?
  end


  private

  def assign_pending_associations
    # Only run this on initial save, not on subsequent updates
    return unless @pending_sector_ids || @pending_category_ids

    if @pending_sector_ids
      self.sectors = Sector.where(id: @pending_sector_ids)
      @pending_sector_ids = nil
    end

    if @pending_category_ids
      self.categories = Category.where(id: @pending_category_ids)
      @pending_category_ids = nil
    end
  end
end
