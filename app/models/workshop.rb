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
  scope :published, -> { where(inactive: false) }
  scope :featured, -> { where(featured: true) }
  scope :by_year, -> { order(year: :desc).order(month: :desc) }
  scope :recent, -> { for_search.by_year.order(led_count: :desc).uniq(&:title) }
  scope :by_rating, -> { by_year.sort_by(&:rating)}
  scope :by_warm_up_and_relaxation, -> { search('Warm Up Relaxation') }
  scope :by_led_count, -> { order(led_count: :desc) }
  scope :for_search, -> { published }
  scope :legacy, -> { where(legacy: true) }
  scope :by_created_at, -> { order(created_at: :desc) }

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

  def date
    if month.nil? or year.nil?
      "#{created_at.month}/#{created_at.year}"
    else
      "#{month}/#{year}"
    end
  end

  def self.search(params)
    workshops = all.order(:title)
    workshops = workshops.search_by_categories( params[:categories] ).order(:title) if params[:categories]
    workshops = workshops.search_by_sectors( params[:sectors] ).order(:title) if params[:sectors]

    if params[:type] == "led"
      workshops = workshops.order(led_count: :desc)
    elsif params[:type] and params[:type] != 'created'
      workshops = workshops.where(windows_type_id: params[:type].to_i).order(:title)
      type_sql  = "AND windows_type_id = #{params[:type]}"
    end

    cols = "title, full_name, objective, materials, introduction, demonstration, opening_circle, warm_up, creation, closing, notes, tips, misc1, misc2"

    query_str = "SELECT *, MATCH ( #{cols} ) AGAINST ( '*#{params[:query]}*' IN BOOLEAN MODE ) AS all_score,
                 MATCH ( title ) AGAINST ( '*#{params[:query]}*' IN BOOLEAN MODE ) AS title_score

                 FROM workshops WHERE MATCH ( #{cols} )
                 AGAINST ( '*#{params[:query]}*' IN BOOLEAN MODE ) #{type_sql} AND inactive is false ORDER BY title_score DESC;"

    unless params[:query].blank?
      workshops = workshops.find_by_sql(query_str)
    end

    if params[:type] == 'created'
      workshops = workshops.sort{|x,y| Date.parse(y.date) <=> Date.parse(x.date) }
    end

    workshops
  end

  def self.search_by_categories(categories)
    categories = categories.to_unsafe_h.map{|k,v| v}
    citems = CategorizableItem.where(categorizable_type: "Workshop",
                                     category_id:  categories)

    where(:id => citems.map{|ci| ci.categorizable_id} )
  end

  def self.search_by_sectors(sectors)
    sectors = sectors.to_unsafe_h.map{|k,v| v}
    sectorable_items = SectorableItem.where(sectorable_type: "Workshop",
                                            sector_id:  sectors)

    where( :id =>  sectorable_items.map{|si| si.sectorable_id} )
  end

  def author_name
    return unless user
    user.full_name
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

  def self.grouped_by_sector
    Sector.all.map { |sector| Hash[sector.name, sector.workshops] }.flatten
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
