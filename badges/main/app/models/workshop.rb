class Workshop < ApplicationRecord
  attr_accessor :time_hours, :time_minutes

  before_save :set_time_frame

  # Associations
  belongs_to :user, optional: true
  belongs_to :windows_type

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

  has_attached_file :thumbnail, default_url: "/images/workshop_default.jpg"
  validates_attachment_content_type :thumbnail, content_type: /\Aimage\/.*\Z/

  has_attached_file :header, default_url: "/images/workshop_default.jpg"
  validates_attachment_content_type :header, content_type: /\Aimage\/.*\Z/


  # Nested Attributes
  accepts_nested_attributes_for :images, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :sectorable_items,
                                reject_if: proc { |object| object['_create'] == '0' },
                                allow_destroy: true
  accepts_nested_attributes_for :sectors,
                                reject_if: proc { |object| object['_create'] == '0' || !object['_create'] },
                                allow_destroy: true
  accepts_nested_attributes_for :workshop_age_ranges,
                                reject_if: proc { |object|
                                  object['_create'] == '0' || !object['_create'] ||
                                  WorkshopAgeRange.find_by(workshop_id: object[:workshop_id], age_range_id: object[:age_range_id]);
                                },
                                allow_destroy: true
  accepts_nested_attributes_for :quotes,
                                reject_if: proc { |object| object['quote'].nil? }

  accepts_nested_attributes_for :workshop_variations,
                                reject_if: proc { |object| object.nil? }

  accepts_nested_attributes_for :workshop_series_children,
                                reject_if: proc { |attributes| attributes['workshop_child_id'].blank? },
                                allow_destroy: true

  # Scopes
  scope :for_search, -> { published }

  scope :featured, -> { where(featured: true) }
  scope :legacy, -> { where(legacy: true) }
  scope :published, -> (published=nil) { published.to_s.present? ? where(inactive: !published) : where(inactive: false) }
  scope :recent, -> { for_search.by_year.order(led_count: :desc).uniq(&:title) }
  scope :title, -> (title) { where("title like ?", "%#{ title }%") }
  scope :windows_type_ids, ->(windows_type_ids) { where(windows_type_id: windows_type_ids) }

  scope :by_created_at, -> { order(created_at: :desc) }
  scope :by_led_count, -> { order(led_count: :desc) }
  scope :by_rating, -> { by_year.sort_by(&:rating)}
  scope :by_warm_up_and_relaxation, -> { search('Warm Up Relaxation') }
  scope :by_year, -> { order(year: :desc).order(month: :desc) }


  # Validations
  validates_presence_of :title
  #validates_presence_of :month, :year, if: Proc.new { |workshop| workshop.legacy }
  validates_length_of :age_range, maximum: 16

  # Nested Attributes
  accepts_nested_attributes_for :workshop_logs,
                                reject_if: :all_blank,
                                allow_destroy: true

  attr_writer :time_hours, :time_minutes

  # Search Cop
  include SearchCop

  search_scope :search do
    attributes :title
    attributes category: ['categories.name']
    attributes sector: ['sectors.name']
  end

  def self.grouped_by_sector
    Sector.all.map { |sector| Hash[sector.name, sector.workshops] }.flatten
  end

  def self.filter_by_params(params={})
    workshops = self.all
    # filter by
    if params[:windows_types].present?
      windows_type_ids = params[:windows_types].values.map(&:to_i) # windows_types param is like {"1"=>"1", "2"=>"1"}
      workshops = workshops.windows_type_ids(windows_type_ids)
    end
    if params[:active].present? || params[:inactive].present?
      active = params[:active] == "true"
      inactive = params[:inactive] == "true"

      if active && !inactive
        workshops = workshops.published(true)
      elsif !active || inactive
        workshops = workshops.published(false)
      end
    end
    if params[:categories].present?
      workshops = workshops.search_by_categories( params[:categories] )
    end
    if params[:sectors].present?
      workshops = workshops.search_by_sectors( params[:sectors] )
    end
    if params[:title].present?
      workshops = workshops.title(params[:title])
    end
    if params[:query].present?
      workshops = workshops.filter_by_query(params[:query])
    end
    workshops
  end

  def self.filter_by_query(query = nil)
    return all if query.blank?

    # Whitelisted, quoted column names to use in search
    cols = %w[title full_name objective materials introduction demonstration opening_circle
              warm_up creation closing notes tips misc1 misc2].
           map { |c| connection.quote_column_name(c) }.join(", ")
    # Prepare query for BOOLEAN MODE (prefix matching)
    terms = query.to_s.strip.split.map { |term| "#{term}*" }.join(" ")
    # Convert to Arel for safety
    match_expr = Arel.sql("MATCH(#{cols}) AGAINST(? IN BOOLEAN MODE)")

    select(
      sanitize_sql_array(["workshops.*, #{match_expr} AS all_score", terms])
    ).where(match_expr, terms)
  end

  def self.search(params, super_user: false)
    workshops = self.filter_by_params(params)

    # only show published results to regular users
    unless super_user
      workshops = workshops.published
    end

    # sort by
    if params[:sort] == 'created'
      workshops = workshops.order(
        Arel.sql("
          CASE
            WHEN year IS NOT NULL AND month IS NOT NULL THEN
              STR_TO_DATE(CONCAT(year,'-',month,'-01'), '%Y-%m-%d')
            ELSE workshops.created_at
          END DESC")
      )
    elsif params[:sort] == 'led'
      workshops = workshops.order(led_count: :desc)
    elsif params[:sort] == "title"
      workshops = workshops.order(title: :asc)
    elsif params[:query].present? # params[:sort] == 'keywords'
      workshops = workshops.order("all_score DESC")
    else
      workshops = workshops.order(title: :asc)
    end

    if params[:type] == 'led' # TODO - find wherever this gets used and change param name to :sort
      workshops = workshops.order(led_count: :desc)
    end

    workshops
  end

  def self.search_by_categories(categories)
    category_ids = categories.to_unsafe_h.values.reject(&:blank?)
    return all if category_ids.empty?
    joins(:categorizable_items)
      .where(categorizable_items: { categorizable_type: "Workshop", category_id: category_ids })
      .distinct
  end

  def self.search_by_sectors(sectors)
    sector_ids = sectors.to_unsafe_h.values.reject(&:blank?)
    return all if sector_ids.empty?
    joins(:sectorable_items)
      .where(sectorable_items: { sectorable_type: "Workshop", sector_id: sector_ids })
      .distinct
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
      form_builder.forms[0].form_fields.where('ordering is not null and status = 1').
        order(ordering: :desc).all
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
      'workshop_default.jpg'
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
    if legacy
      decorate.main_image
    elsif images.first
      "http://awbw-production.herokuapp.com#{images.first.file.url}"
    end
  end

  def sector_hashtags
    sectors.map do |sector|
      "\##{sector.name.split(' ')[0].downcase}"
    end.join(',')
  end

  def admin_title
    "#{title} - #{windows_type.label if windows_type}"
  end

  def log_title
    "#{title} #{windows_type.log_label if windows_type}"
  end

  def communal_label(report)
    "Workshop Title: #{title} - Workshop Date: #{report.date ? report.date.strftime('%m/%d/%y') : '[ EMPTY ]'}"
  end

  def published_sectors
    sectorable_items.where(inactive: false).map { |item| item.sector }
  end

  def time_frame_total
    total_time = time_intro.to_i    + time_demonstration.to_i +
                 time_opening.to_i  + time_warm_up.to_i +
                 time_creation.to_i + time_closing.to_i

    return ("00:00") if total_time == 0

    Time.at(total_time * 60).utc #.strftime("%H:%M")
  end

  def set_time_frame
    unless @time_hours.blank? && @time_minutes.blank?
      self.timeframe = "#{@time_hours}:#{@time_minutes}"
    end
  end

  def self.anchors_english_admin
    "<a name='top'></a>".html_safe
    %w(extra_field objective materials optional_materials setup
      introduction demonstration opening_circle warm_up visualization creation
      closing notes tips).map {|field|
        "<a href='#workshop_#{field}_field'>#{field.capitalize}</a> |"}.join(" ").html_safe
  end

   def self.anchors_spanish_admin
     %w(extra_field_spanish objective_spanish materials_spanish optional_materials_spanish
      timeframe_spanish age_range_spanish setup_spanish introduction_spanish
      demonstration_spanish opening_circle_spanish warm_up_spanish visualization_spanish
      creation_spanish closing_spanish notes_spanish tips_spanish misc1_spanish
      misc2_spanish).map {|field|
        "<a href='#workshop_#{field}_field'>#{field.capitalize}</a> |"}.join(" ").html_safe
   end
end
