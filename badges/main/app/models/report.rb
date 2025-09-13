class Report < ApplicationRecord
  belongs_to :user
  belongs_to :project
  belongs_to :windows_type

  belongs_to :owner, polymorphic: true, optional: true
  has_one  :form, as: :owner
  has_one  :image
  validate :image_valid?
  has_attached_file :form_file

  before_save :set_has_attachament

  FORM_FILE_CONTENT_TYPES = %w[application/pdf application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document application/vnd.ms-excel application/vnd.openxmlformats-officedocument.spreadsheetml.sheet]

  validates_attachment :form_file, content_type: { content_type:  FORM_FILE_CONTENT_TYPES }

  has_many :images
  has_many :form_fields, through: :form
  has_many :report_form_field_answers, dependent: :destroy
  has_many :quotable_item_quotes, as: :quotable, dependent: :destroy
  has_many :quotes, through: :quotable_item_quotes, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :sectors, through: :sectorable_items, dependent: :destroy
  scope :in_month, -> (date) { where(created_at: date.beginning_of_month..date.end_of_month) }

  has_many :media_files, dependent: :destroy
  accepts_nested_attributes_for :media_files

  accepts_nested_attributes_for :report_form_field_answers,
                                reject_if: proc { |object|
                                  (object['_create'].to_i == 0 && object['answer'].nil?)
                                }
  accepts_nested_attributes_for :quotable_item_quotes

  after_create :set_windows_type
  after_save :create_admin_notification

  def users_admin_type
    if form_builder && form_builder.id == 7
      "Story"
    else
      case type
      when "MonthlyReport"
        "#{type} - Monthly Report Date: #{date_label} - User: #{user.full_name if user}"
      when "Report"
        if owner_type and owner_type == 'Resource'
          "#{type} - #{owner ? owner_type : '[ EMPTY ]'} - User: #{user.full_name if user}"
        else
           "#{type} - #{owner ? owner.type : '[ EMPTY ]'} - User: #{user.full_name if user}"
        end
      else
        "#{type} - #{owner ? owner.communal_label(self) : '[ EMPTY ]'} - User: #{user.full_name if user}"
      end
    end
  end

  def story?
    form_builder && form_builder.id == 7
  end

  def date_label
    "#{date ? date.strftime('%m/%d/%y') : '[ EMPTY ]'}"
  end

  def delete_and_update_all(quotes_params, log_fields, image = nil)
    self.quotes.delete_all
    self.report_form_field_answers.delete_all

    self.quotes.build( quotes_params )
    self.report_form_field_answers.build( log_fields )

    unless image.blank?
      self.image.destroy if self.image
      self.image = Image.new( file: image )
    end

    save
  end

  def image_valid?
    return true if image.nil?
    unless image.valid?
      image.errors.each do |k, v|
        errors.add(k, v)
      end
    end
  end

  def log_fields
    if form_builder
      form_builder.forms[0].form_fields.where('ordering is not null and status = 1').
        order(ordering: :desc).all
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
    type ? type.titleize : 'Report'
  end

  def display_date
    created_at.strftime('%B %e, %Y')
  end

  private

  def set_has_attachament
    self.has_attachment = false

    unless self.image.blank? and self.media_files.empty? and self.form_file.blank?
      self.has_attachment = true
    end
  end

  def set_windows_type
    return unless project && windows_type.nil?
    update(windows_type_id: project.windows_type.id)
  end

  def create_admin_notification
    notifications.create(notification_type: 0)
  end
end
