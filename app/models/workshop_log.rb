class WorkshopLog < Report
  belongs_to :workshop
  belongs_to :user
  belongs_to :project

  has_many :media_files

  # Callbacks
  after_save :update_workshop_log_count

  def name
    return "" unless user
    "#{user.name}"
  end

  def workshop_title
    title = owner.nil? ? workshop_name : owner.title
    return "" unless title
    title
  end

  def type_title
    if windows_type
      "#{windows_type.workshop_log_label} #{type}"
    else
      "#{type}"
    end
  end

  def owner_title
    workshop_title = owner.nil? ? workshop_name : owner.title
    return "" unless workshop_title && windows_type

    if !owner.nil?
      title = "#{workshop_title} - #{owner.windows_type.label}"
     "<a class='pjax' href='/admin/cms/workshop/#{owner.id}'>#{title}</a>".html_safe
    else
      title = "#{workshop_title} - #{windows_type.label}"
      "#{title}"
    end
  end

  def title
    workshop_title = owner.nil? ? workshop_name : owner.title
    return unless workshop_title
    "Workshop Log - #{workshop_title}"
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

  def date_label
   date ? date.strftime('%m/%d/%Y') : created_at.strftime('%m/%d/%Y')
  end

  private

  def update_workshop_log_count
    return unless owner
    new_led_count = owner.workshop_logs.count
    owner.update(led_count: new_led_count)
  end

  protected

end
