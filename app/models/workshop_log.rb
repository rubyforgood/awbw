class WorkshopLog < Report
  belongs_to :workshop
  belongs_to :user
  belongs_to :project
  has_many :quotable_item_quotes, as: :quotable, dependent: :nullify, inverse_of: :quotable
  has_many :quotes, through: :quotable_item_quotes
  has_many :report_form_field_answers,
           foreign_key: :report_id, inverse_of: :report,
           dependent: :destroy
  # Image associations
  has_many :media_files, dependent: :destroy # TODO - convert these to GalleryImages
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Nested attributes
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :quotable_item_quotes, allow_destroy: true,
                                reject_if: ->(attributes) { false } # allow empty
  accepts_nested_attributes_for :report_form_field_answers, allow_destroy: true,
                                reject_if: ->(attributes) { false } # allow empty

  # Validations
  validates :children_ongoing, :teens_ongoing, :adults_ongoing,
            :children_first_time, :teens_first_time, :adults_first_time,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :date, presence: true

  # Callbacks
  after_save :update_owner_and_date
  after_save :update_workshop_log_count

  # Scopes
  scope :workshop_id, ->(workshop_id) { where(workshop_id: workshop_id) if workshop_id.present? }
  scope :project_id, ->(project_id) { where(project_id: project_id) if project_id.present? }
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

  def self.search(params)
    logs = all
    logs = logs.user_id(params[:user_id]) if params[:user_id].present?
    logs = logs.month_and_year(params[:month_and_year]) if params[:month_and_year].present?
    logs = logs.year(params[:year]) if params[:year].present?
    logs = logs.workshop_id(params[:workshop_id]) if params[:workshop_id].present?
    logs = logs.project_id(params[:project_id]) if params[:project_id].present?
    logs.ordered_by_date
  end

  def name
    return "" unless user
    "#{user.name}"
  end

  def full_name
    "#{ date.strftime("%m-%d-%Y") if date }: #{workshop_title} - #{type_title}"
  end

  def workshop_title
    title = owner.nil? ? workshop_name : owner.title
    return "" unless title
    title
  end

  def type_title
    if windows_type
      "#{windows_type.label} #{type}"
    else
      "#{type}"
    end
  end

  def title
    workshop_title = owner.nil? ? workshop_name : owner.title
    return unless workshop_title
    "Workshop Log - #{workshop_title}"
  end

  def total_attendance
    children_ongoing + teens_ongoing + adults_ongoing +
      children_first_time + teens_first_time + adults_first_time
  end

  def num_ongoing
    field_ids = FormField.where('question LIKE ? OR ?', '%on-going%', '%ongoing%')
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def num_first_time
    field_ids = FormField.where('question LIKE ?', '%first%')
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def combined_num_ongoing(field_type)
    ongoing = "%Ongoing #{field_type}"
    field_ids = FormField.where('question LIKE ?', "%#{ongoing}%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def combined_num_first_time(field_type)
    first_time = "First-time #{field_type}"
    field_ids = FormField.where('question LIKE ?', "%#{first_time}%")
    report_form_field_answers.where(form_field_id: field_ids)
      .sum(:answer).to_i if field_ids.any?
  end

  def form_builder
    FormBuilder
      .workshop_logs
      .find_by(windows_type: windows_type)
  end

  def log_fields
    if form_builder
      form_builder.forms[0].form_fields.where('ordering is not null and status = 1').
        order(ordering: :desc).all
    else
      []
    end
  end

  def description
    "Workshop Log for #{workshop_title} led by #{name} on #{date_label}"
  end

  def date_label
   date ? date.strftime('%m/%d/%Y') : created_at.strftime('%m/%d/%Y')
  end

  def workshop_quotes
    workshop&.quotes || Quote.none
  end

  private

  def update_workshop_log_count
    return unless owner
    new_led_count = owner.workshop_logs.size
    owner.update(led_count: new_led_count)
  end

  def update_owner_and_date
    changes = {}
    changes[:date] = created_at if date.blank?
    changes[:owner_id] = workshop_id if owner_id.blank?
    update_columns(changes) if changes.any?
  end

  protected

end
