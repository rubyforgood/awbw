class WorkshopLog < Report
  # Validations
  validates :date, presence: true
  validates :children_ongoing, :teens_ongoing, :adults_ongoing,
            :children_first_time, :teens_first_time, :adults_first_time,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # Callbacks
  after_save :update_owner_and_date
  after_save :update_workshop_log_count

  # Scopes
  # See report.rb

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

  def workshop_name
    workshop&.title
  end

  def windows_type_name
    windows_type&.short_name
  end

  def type_title
    if windows_type
      "#{windows_type_name} #{type}"
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

  def form_builder
    FormBuilder
      .workshop_logs
      .find_by(windows_type: windows_type)
  end

  def log_fields
    if form_builder
      form_builder.forms[0].form_fields.where("position is not null and status = 1").
        order(position: :desc).all
    else
      []
    end
  end

  def description
    "Workshop Log for #{workshop_title} led by #{name} on #{date_label}"
  end

  def date_label
    date ? date.strftime("%m/%d/%Y") : created_at.strftime("%m/%d/%Y")
  end

  def workshop_quotes
    workshop&.quotes || Quote.none
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

  def update_workshop_log_count
    return unless owner
    new_led_count = owner.workshop_logs.size
    owner.update(led_count: new_led_count)
  end

  def update_owner_and_date
    changes = {}
    changes[:date] = created_at if date.blank?
    changes[:owner_id] = workshop_id if owner_id.blank?
    changes[:owner_type] = "Workshop" if workshop_id
    update_columns(changes) if changes.any?
  end
end
