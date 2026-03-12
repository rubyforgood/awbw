class WorkshopLog < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :organization
  belongs_to :windows_type
  belongs_to :workshop, optional: true
  has_one :form, as: :owner
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy, autosave: false
  has_many :quotable_item_quotes, as: :quotable, dependent: :nullify, inverse_of: :quotable
  has_many :report_form_field_answers,
           foreign_key: :workshop_log_id, inverse_of: :workshop_log,
           dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy

  # Asset associations
  has_many :media_files, dependent: :destroy
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  # has_many through
  has_many :form_fields, through: :form
  has_many :all_quotable_item_quotes,
           ->(wl) { where(quotable_id: wl.id, quotable_type: "WorkshopLog") },
           class_name: "QuotableItemQuote",
           inverse_of: :quotable
  has_many :quotes, through: :all_quotable_item_quotes, dependent: :nullify
  has_many :sectors, through: :sectorable_items, dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :media_files, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :all_quotable_item_quotes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :quotable_item_quotes, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :report_form_field_answers,
                                reject_if: proc { |object|
                                  object["_create"].to_i == 0 && object["answer"].nil? }

  # Validations
  validates :date, presence: true
  validates :children_ongoing, :teens_ongoing, :adults_ongoing,
            :children_first_time, :teens_first_time, :adults_first_time,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :workshop_or_external_title_present

  # Callbacks
  before_save :compute_totals
  after_commit :update_workshop_log_count, on: [ :create, :update ]

  # Scopes
  scope :in_month, ->(date) { where(created_at: date.beginning_of_month..date.end_of_month) }
  scope :workshop_id, ->(workshop_id) { where(workshop_id: workshop_id) if workshop_id.present? }
  scope :organization_id, ->(organization_id) { where(organization_id: organization_id) if organization_id.present? }
  scope :organization_ids, ->(organization_ids) { where(organization_id: organization_ids) }
  scope :created_by_id, ->(created_by_id) { where(created_by_id: created_by_id.to_i) if created_by_id.present? }
  scope :month_and_year, ->(month_and_year) {
    if month_and_year.present?
      year, month = month_and_year.split("-").map(&:to_i)
      where("EXTRACT(YEAR FROM COALESCE(workshop_logs.date, workshop_logs.created_at)) = ? AND
               EXTRACT(MONTH FROM COALESCE(workshop_logs.date, workshop_logs.created_at)) = ?", year, month)
    end }
  scope :year, ->(year) {
    if year.present?
      where("EXTRACT(YEAR FROM COALESCE(workshop_logs.date, workshop_logs.created_at)) = ?", year.to_i)
    end }
  scope :ordered_by_date, -> { order(Arel.sql("COALESCE(workshop_logs.date, workshop_logs.created_at) DESC")) }

  def self.search(params)
    logs = is_a?(ActiveRecord::Relation) ? self : all
    logs = logs.created_by_id(params[:created_by_id]) if params[:created_by_id].present?
    logs = logs.month_and_year(params[:month_and_year]) if params[:month_and_year].present?
    logs = logs.year(params[:year]) if params[:year].present?
    logs = logs.workshop_id(params[:workshop_id]) if params[:workshop_id].present?
    logs = logs.organization_id(params[:organization_id]) if params[:organization_id].present?
    logs.ordered_by_date
  end

  def name
    return "" unless created_by
    "#{created_by.name}"
  end

  def full_name
    type_label = windows_type ? "#{windows_type_name} WorkshopLog" : "WorkshopLog"
    "#{ date.strftime("%m-%d-%Y") if date }: #{workshop_title} - #{type_label}"
  end

  def workshop_title
    title = workshop&.title.presence || workshop_name
    title = external_workshop_title if title.blank?
    return "" unless title
    title
  end

  def windows_type_name
    windows_type&.short_name
  end

  def title
    wt = workshop&.title.presence || workshop_name
    return unless wt
    "Workshop Log - #{wt}"
  end

  def total_attendance
    children_ongoing + teens_ongoing + adults_ongoing +
      children_first_time + teens_first_time + adults_first_time
  end

  def num_ongoing
    field_ids = FormField.where("question LIKE ? OR ?", "%on-going%", "%ongoing%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def num_first_time
    field_ids = FormField.where("question LIKE ?", "%first%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def combined_num_ongoing(field_type)
    ongoing = "%Ongoing #{field_type}"
    field_ids = FormField.where("question LIKE ?", "%#{ongoing}%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def combined_num_first_time(field_type)
    first_time = "First-time #{field_type}"
    field_ids = FormField.where("question LIKE ?", "%#{first_time}%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def description
    "Workshop Log for #{workshop_title} led by #{name} on #{date_label}"
  end

  def date_label
    date ? date.strftime("%m/%d/%Y") : created_at.strftime("%m/%d/%Y")
  end

  def attendance_breakdown
    {
      children: {
        first: children_first_time,
        ongoing: children_ongoing
      },
      teens: {
        first: teens_first_time,
        ongoing: teens_ongoing
      },
      adults: {
        first: adults_first_time,
        ongoing: adults_ongoing
      }
    }
  end

  def totals
    attendance_breakdown.transform_values do |v|
      v[:first] + v[:ongoing]
    end.merge(
      first_time: children_first_time + teens_first_time + adults_first_time,
      ongoing: children_ongoing + teens_ongoing + adults_ongoing,
      overall: total_attendance
    )
  end

  private

  def compute_totals
    self.total_children = children_first_time + children_ongoing
    self.total_teens = teens_first_time + teens_ongoing
    self.total_adults = adults_first_time + adults_ongoing
  end

  def workshop_or_external_title_present
    return if workshop.present? || external_workshop_title.present?
    errors.add(:base, "Please select a workshop or provide an external workshop title")
  end

  def update_workshop_log_count
    return unless workshop
    new_led_count = workshop.workshop_logs.size
    workshop.update(led_count: new_led_count)
  end
end
