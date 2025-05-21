class WorkshopLog < Report
  belongs_to :workshop
  belongs_to :user
  belongs_to :project

  has_many :media_files

  # Callbacks
  after_save :update_workshop_log_count

  rails_admin do
    configure :created_at do
      show
    end
    configure :updated_at do
      show
    end

    list do
      field :id
      field :type
      field :workshop_name do
        label 'owner'
        filterable true
        searchable true
        queryable true
      end
      field :windows_type do
        filterable true
        visible false
        queryable true
        searchable [:short_name]
      end
      field :created_at
      field :updated_at
      field :user do
        queryable true
        searchable [:first_name, :last_name]
      end

      configure :workshop_name do
        formatted_value{ bindings[:object].owner_title}
      end

      configure :type do
        formatted_value{ bindings[:object].type_title}
      end

      exclude_fields :type
    end

    show do
      field :owner
      field :user
      field :project
      field :date
      field :rating
      field :children_ongoing
      field :teens_ongoing
      field :adults_ongoing
      field :children_first_time
      field :teens_first_time
      field :adults_first_time
      field :quotable_item_quotes
      field :quotes
      field :media_files

      configure :adults_ongoing do
        formatted_value{ bindings[:object].adults_ongoing}
      end
      configure :teens_ongoing do
        formatted_value{ bindings[:object].teens_ongoing}
      end
      configure :children_ongoing do
        formatted_value{ bindings[:object].children_ongoing}
      end
      configure :adults_first_time do
        formatted_value{ bindings[:object].adults_first_time}
      end
      configure :teens_first_time do
        formatted_value{ bindings[:object].teens_first_time}
      end
      configure :children_first_time do
        formatted_value{ bindings[:object].children_first_time}
      end

      exclude_fields :type
    end

    edit do
      field :owner
      field :user
      field :project
      field :date
      field :rating
      field :children_ongoing
      field :teens_ongoing
      field :adults_ongoing
      field :children_first_time
      field :teens_first_time
      field :adults_first_time
      field :quotable_item_quotes
      field :quotes
      field :media_files

      configure :adults_ongoing do
        formatted_value{ bindings[:object].adults_ongoing}
      end
      configure :teens_ongoing do
        formatted_value{ bindings[:object].teens_ongoing}
      end
      configure :children_ongoing do
        formatted_value{ bindings[:object].children_ongoing}
      end
      configure :adults_first_time do
        formatted_value{ bindings[:object].adults_first_time}
      end
      configure :teens_first_time do
        formatted_value{ bindings[:object].teens_first_time}
      end
      configure :children_first_time do
        formatted_value{ bindings[:object].children_first_time}
      end

      exclude_fields :type
    end

  end

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
