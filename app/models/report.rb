class Report < ApplicationRecord
  belongs_to :owner, polymorphic: true, optional: true
  belongs_to :user
  belongs_to :organization
  belongs_to :windows_type
  belongs_to :workshop
  has_one :form, as: :owner
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :quotable_item_quotes, as: :quotable, dependent: :nullify, inverse_of: :quotable
  has_many :report_form_field_answers,
           foreign_key: :report_id, inverse_of: :report,
           dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # Images
  has_one_attached :image # old paperclip -- TODO convert these to MainImage records
  has_one_attached :form_file # old paperclip -- TODO convert these to GalleryImage records
  # Asset associations
  has_many :media_files, dependent: :destroy # TODO - convert to GalleryImages
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  # has_many through
  has_many :form_fields, through: :form
  has_many :all_quotable_item_quotes,
           ->(wl) { where(quotable_id: wl.id,
                          quotable_type: %w[WorkshopLog Report]) }, # needed bc some are stored w type Report
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
  FORM_FILE_CONTENT_TYPES = %w[application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]
  validates :form_file, content_type: FORM_FILE_CONTENT_TYPES

  before_save :set_has_attachment # TODO verify set_has_attachment works as expected once this feature is enabled in the UI
  after_create :set_windows_type
  after_save :create_notification

  # Scopes
  scope :in_month, ->(date) { where(created_at: date.beginning_of_month..date.end_of_month) }
  scope :workshop_id, ->(workshop_id) { where(workshop_id: workshop_id) if workshop_id.present? }
  scope :organization_id, ->(organization_id) { where(organization_id: organization_id) if organization_id.present? }
  scope :user_id, ->(user_id) { where(user_id: user_id.to_i) if user_id.present? }
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
  scope :workshop_logs, -> { where(type: "WorkshopLog") }

  def self.search(params)
    logs = is_a?(ActiveRecord::Relation) ? self : all
    logs = logs.user_id(params[:user_id]) if params[:user_id].present?
    logs = logs.month_and_year(params[:month_and_year]) if params[:month_and_year].present?
    logs = logs.year(params[:year]) if params[:year].present?
    logs = logs.workshop_id(params[:workshop_id]) if params[:workshop_id].present?
    logs = logs.organization_id(params[:organization_id]) if params[:organization_id].present?
    logs.ordered_by_date
  end

  def users_admin_type
    if form_builder && form_builder.id == 7
      "Story"
    else
      case type
      when "MonthlyReport"
        "#{type} - Monthly Report Date: #{date_label} - User: #{user.full_name if user}"
      when "Report"
        if owner_type and owner_type == "Resource"
          "#{type} - #{owner ? owner_type : "[ EMPTY ]"} - User: #{user.full_name if user}"
        else
          "#{type} - #{owner ? owner.type : "[ EMPTY ]"} - User: #{user.full_name if user}"
        end
      else
        "#{type} - #{owner ? owner.communal_label(self) : "[ EMPTY ]"} - User: #{user.full_name if user}"
      end
    end
  end

  def story?
    form_builder && form_builder.id == 7
  end

  def date_label
    "#{date ? date.strftime("%m/%d/%y") : "[ EMPTY ]"}"
  end

  def delete_and_update_all(quotes_params, log_fields, image = nil)
    # self.quotes.delete_all # TODO - figure out why this was deleting quotes and quote_item_quotes
    # self.report_form_field_answers.delete_all # TODO - figure out why this was deleting quotes and quote_item_quotes

    # self.quotes.build( quotes_params )
    # self.report_form_field_answers.build( log_fields )

    unless image.blank?
      self.image.destroy if self.image
      self.image = Image.new(file: image)
    end

    save
  end

  def log_fields
    if form_builder
      form_builder.forms[0].form_fields.where("position is not null and status = 1")
        .order(position: :desc).all
    else
      []
    end
  end

  def form_builder
    if type and type.include? "Monthly"
      if windows_type and windows_type.name == "ADULT WORKSHOP LOG"
        FormBuilder.find(4)
      elsif windows_type and windows_type.name == "CHILDREN WORKSHOP LOG"
        FormBuilder.find(2)
      end
    elsif owner and owner_type.include? "FormBuilder"
      FormBuilder.find(7)
    else
      nil
    end
  end

  def user_name
    user.name
  end

  def title
    name
  end

  def name
    type ? type.titleize : "Report"
  end

  def display_date
    created_at.strftime("%B %e, %Y")
  end

  private

  def set_has_attachment
    self.has_attachment = image&.file&.attached? || form_file&.attached? ||
      media_files.any? { |media_file| media_file.file.attached? }
  end

  def set_windows_type
    return unless organization && windows_type.nil?
    update(windows_type_id: organization.windows_type.id)
  end

  def create_notification
    notifications.create(notification_type: 0)
  end
end
