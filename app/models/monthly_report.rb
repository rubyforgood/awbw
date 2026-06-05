class MonthlyReport < Report
  PARTICIPANT_ONGOING_QUESTION = "Total # On-going Participants"
  PARTICIPANT_FIRST_TIME_QUESTION = "Total # First-Time Participants"

  FORM_FILE_CONTENT_TYPES = %w[application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]

  # Associations (override Report's)
  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :organization
  belongs_to :windows_type
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy, autosave: false
  has_many :quotable_item_quotes, as: :quotable, dependent: :nullify, inverse_of: :quotable
  has_many :report_form_field_answers,
           foreign_key: :report_id, inverse_of: :report,
           dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy

  # Images (legacy paperclip; TODO convert to MainImage / GalleryImage records)
  has_one_attached :image
  has_one_attached :form_file

  # Asset associations
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  # has_many through
  has_many :all_quotable_item_quotes,
           ->(r) { where(quotable_id: r.id, quotable_type: "Report") },
           class_name: "QuotableItemQuote",
           inverse_of: :quotable
  has_many :quotes, through: :all_quotable_item_quotes, dependent: :nullify
  has_many :sectors, through: :sectorable_items, dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :all_quotable_item_quotes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :quotable_item_quotes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :report_form_field_answers,
                                reject_if: proc { |object|
                                  object["_create"].to_i == 0 && object["answer"].nil? }

  validates :form_file, content_type: FORM_FILE_CONTENT_TYPES

  before_save :set_has_attachment
  after_create :set_windows_type

  # Scopes
  scope :in_month, ->(date) { where(created_at: date.beginning_of_month..date.end_of_month) }
  scope :organization_id, ->(organization_id) { where(organization_id: organization_id) if organization_id.present? }
  scope :organization_ids, ->(organization_ids) { where(organization_id: organization_ids) }
  scope :created_by_id, ->(created_by_id) { where(created_by_id: created_by_id.to_i) if created_by_id.present? }
  scope :month_and_year, ->(month_and_year) {
    if month_and_year.present?
      year, month = month_and_year.split("-").map(&:to_i)
      where("EXTRACT(YEAR FROM COALESCE(reports.date, reports.created_at)) = ? AND
               EXTRACT(MONTH FROM COALESCE(reports.date, reports.created_at)) = ?", year, month)
    end }
  scope :year, ->(year) {
    if year.present?
      where("EXTRACT(YEAR FROM COALESCE(reports.date, reports.created_at)) = ?", year.to_i)
    end }
  scope :ordered_by_date, -> { order(Arel.sql("COALESCE(reports.date, reports.created_at) DESC")) }

  def self.participant_field_ids(question)
    FormField.where(name: question, status: 1).pluck(:id)
  end

  def self.search(params)
    logs = is_a?(ActiveRecord::Relation) ? self : all
    logs = logs.created_by_id(params[:created_by_id]) if params[:created_by_id].present?
    logs = logs.month_and_year(params[:month_and_year]) if params[:month_and_year].present?
    logs = logs.year(params[:year]) if params[:year].present?
    logs = logs.organization_id(params[:organization_id]) if params[:organization_id].present?
    logs.ordered_by_date
  end

  def month
    date.strftime("%B")
  end

  def users_admin_type
    "MonthlyReport - Monthly Report Date: #{date_label} - User: #{created_by.full_name if created_by}"
  end

  def date_label
    "#{date ? date.strftime("%m/%d/%y") : "[ EMPTY ]"}"
  end

  def user_name
    created_by.name
  end

  def title
    name
  end

  def name
    "Monthly Report ##{id}"
  end

  def display_date
    created_at.strftime("%B %e, %Y")
  end

  def on_going_participants
    if form_builder
      field = form_builder.form_fields.find_by(name: PARTICIPANT_ONGOING_QUESTION, status: 1)
      field.answer(self) if field
    end
  end

  def new_participants
    if form_builder
      field = form_builder.form_fields.find_by(name: PARTICIPANT_FIRST_TIME_QUESTION, status: 1)
      field.answer(self) if field
    end
  end

  private

  def set_has_attachment
    self.has_attachment = image&.file&.attached? || form_file&.attached?
  end

  def set_windows_type
    return unless organization && windows_type.nil?
    update(windows_type_id: organization.windows_type.id)
  end
end
