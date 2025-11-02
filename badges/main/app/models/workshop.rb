class Workshop < ApplicationRecord
  include Rails.application.routes.url_helpers

  attr_accessor :time_hours, :time_minutes

  before_save :set_time_frame

  # Associations
  belongs_to :user, optional: true
  belongs_to :windows_type

  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png" ].freeze
  has_one_attached :thumbnail
  validates :thumbnail, content_type: ACCEPTED_CONTENT_TYPES

  has_one_attached :header
  validates :header, content_type: ACCEPTED_CONTENT_TYPES

  has_many :sectorable_items, dependent: :destroy,
           inverse_of: :sectorable, as: :sectorable

  has_many :sectors, through: :sectorable_items

  has_many :images, as: :owner, dependent: :destroy
  has_many :workshop_logs, dependent: :destroy, as: :owner
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :workshop_variations, dependent: :destroy

  has_many :categorizable_items, dependent: :destroy, as: :categorizable
  has_many :categories, through: :categorizable_items

  has_many :metadata, through: :categories
  has_many :quotable_item_quotes, as: :quotable, dependent: :destroy
  has_many :quotes, through: :quotable_item_quotes

  has_many :workshop_resources, dependent: :destroy
  has_many :resources, through: :workshop_resources

  has_many :attachments, as: :owner, dependent: :destroy
  has_many :workshop_age_ranges

  # When this workshop is the parent in a series
  has_many :workshop_series_children,
           -> { order(:series_order) },
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_parent_id",
           dependent: :destroy

  # When this workshop is the child in a series
  has_many :workshop_series_parents,
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_child_id",
           dependent: :destroy

  # Nested Attributes
  accepts_nested_attributes_for :images, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :sectorable_items,
    reject_if: proc { |object| object["_create"] == "0" },
    allow_destroy: true
  accepts_nested_attributes_for :sectors,
    reject_if: proc { |object| object["_create"] == "0" || !object["_create"] },
    allow_destroy: true
  accepts_nested_attributes_for :workshop_age_ranges,
    reject_if: proc { |object|
      object["_create"] == "0" || !object["_create"] ||
        WorkshopAgeRange.find_by(workshop_id: object[:workshop_id], age_range_id: object[:age_range_id])
    },
    allow_destroy: true
  accepts_nested_attributes_for :quotes,
    reject_if: proc { |object| object["quote"].nil? }

  accepts_nested_attributes_for :workshop_variations,
    reject_if: proc { |object| object.nil? }

  accepts_nested_attributes_for :workshop_series_children,
                                reject_if: proc { |attributes| attributes['workshop_child_id'].blank? },
                                allow_destroy: true

  # Scopes
  scope :featured, -> { where(featured: true) }
  scope :legacy, -> { where(legacy: true) }
  scope :published, -> (published=nil) { published.to_s.present? ? where(inactive: !published) : where(inactive: false) }
  scope :title, -> (title) { where("workshops.title like ?", "%#{ title }%") }
  scope :windows_type_ids, ->(windows_type_ids) { where(windows_type_id: windows_type_ids) }

  # Validations
  validates_presence_of :title
  # validates_presence_of :month, :year, if: Proc.new { |workshop| workshop.legacy }
  validates_length_of :age_range, maximum: 16
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }

  # Nested Attributes
  accepts_nested_attributes_for :workshop_logs,
    reject_if: :all_blank,
    allow_destroy: true

  attr_writer :time_hours, :time_minutes

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes all: [:title, :full_name, # no spanish alternatives

                     :objective, :materials, :setup, :introduction,
                     :demonstration, :opening_circle, :warm_up, :opening_circle,
                     :creation, :closing, :notes, :tips, :misc1, :misc2,

                     :objective_spanish, :materials_spanish, :setup_spanish, :introduction_spanish,
                     :demonstration_spanish, :opening_circle_spanish, :warm_up_spanish, :opening_circle_spanish,
                     :creation_spanish, :closing_spanish, :notes_spanish, :tips_spanish, :misc1_spanish, :misc2_spanish]
    # attributes category: ["categories.name"]
    # attributes sector: ["sectors.name"]
    # attributes user: ["first_name", "last_name"]
    options :all, type: :text, default: true#, default_operator: :or
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
      "#{month}/#{year}"
    else
      "#{created_at.month}/#{created_at.year}"
    end
  end

  def name
    title
  end

  def workshop_log_fields
    if form_builder
      form_builder.forms[0].form_fields.where("ordering is not null and status = 1")
        .order(ordering: :desc).all
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
    workshop_logs.count
  end

  def main_image_url
    if images&.first&.file&.attached?
      Rails.application.routes.url_helpers.url_for(images.first.file)
    else
      ActionController::Base.helpers.asset_path("workshop_default.png")
    end
  end

  def sector_hashtags
    sectors.map do |sector|
      "\#{sector.name.split(" ")[0].downcase}"
    end.join(",")
  end

  def admin_title
    "#{title} - #{windows_type.label if windows_type}"
  end

  def log_title
    "#{title} #{windows_type.log_label if windows_type}"
  end

  def communal_label(report)
    "Workshop Title: #{title} - Workshop Date: #{report.date ? report.date.strftime("%m/%d/%y") : "[ EMPTY ]"}"
  end

  def published_sectors
    sectorable_items.where(inactive: false).map { |item| item.sector }
  end

  def time_frame_total
    total_time = time_intro.to_i + time_demonstration.to_i +
      time_opening.to_i + time_warm_up.to_i +
      time_creation.to_i + time_closing.to_i

    return "00:00" if total_time == 0

    Time.at(total_time * 60).utc # .strftime("%H:%M")
  end

  def set_time_frame
    unless @time_hours.blank? && @time_minutes.blank?
      self.timeframe = "#{@time_hours}:#{@time_minutes}"
    end
  end

  def self.anchors_english_admin
    "<a name='top'></a>".html_safe
    %w[extra_field objective materials optional_materials setup
      introduction demonstration opening_circle warm_up visualization creation
      closing notes tips].map { |field|
      "<a href='#workshop_#{field}_field'>#{field.capitalize}</a> |" }.join(" ").html_safe
  end

  def self.anchors_spanish_admin
    %w[extra_field_spanish objective_spanish materials_spanish optional_materials_spanish
      timeframe_spanish age_range_spanish setup_spanish introduction_spanish
      demonstration_spanish opening_circle_spanish warm_up_spanish visualization_spanish
      creation_spanish closing_spanish notes_spanish tips_spanish misc1_spanish
      misc2_spanish].map { |field|
      "<a href='#workshop_#{field}_field'>#{field.capitalize}</a> |" }.join(" ").html_safe
  end
end
