class FormField < ApplicationRecord
  belongs_to :form, inverse_of: :form_fields
  has_many :form_field_answer_options, dependent: :destroy
  has_many :report_form_field_answers, dependent: :destroy
  has_many :childs, foreign_key: "parent_id", class_name: "FormField"

  # has_many through
  has_many :answer_options, through: :form_field_answer_options

  # Validations
  validates_presence_of :name

  # Enum
  enum :status, [ :inactive, :active ]
  enum :visibility, [ :always_ask, :scholarship_only, :logged_out_only, :answers_on_file ]

  enum :answer_type, [
    :free_form_input_one_line,
    :free_form_input_paragraph,
    :multiple_choice_radio,
    :no_user_input,
    :multiple_choice_checkbox,
    :group_header
  ]

  enum :input_type, [
    :text_alphanumeric,
    :number_integer,
    :number_decimal,
    :date
  ]

  # Nested attributes
  accepts_nested_attributes_for :form_field_answer_options

  default_scope { order(position: :desc) }
  scope :published, -> { where(status: "active") }

  # Methods
  def multiple_choice?
    answer_type ? answer_type.include?("multiple_choice") : false
  end

  def html_id
    self.name.tr(" /#,')(.", "_").downcase
  end

  def html_input_type
    return :child unless parent_id.nil?

    case answer_type
    when "free_form_input_one_line"
      :text
    when "free_form_input_paragraph"
      :textarea
    when "multiple_choice_checkbox"
      :checkbox
    when "multiple_choice_radio"
      :radio
    when "no_user_input", "group_header"
      childs.any? ? :group_header : :label
    else
      :hidden
    end
  end

  def form_helper_type
    case answer_type
    when "free_form_input_one_line"
      :text_field
    when "free_form_input_paragraph"
      :text_area
    when "multiple_choice_checkbox"
      :check_box
    when "multiple_choice_radio"
      :radio_button
    when "no_user_input", "group_header"
      :label
    else
      :hidden_field
    end
  end

  def find_answer(report)
    return if report.nil?
    report.report_form_field_answers.select { |fa| fa.form_field == self }.first
  end

  def answer(report)
    answer = find_answer(report)
    answer.response unless answer.nil?
  end

  def checked(report, value)
    answer = find_answer(report)

    if answer.nil?
      false
    else
      answer.response == value
    end
  end

  def selected(report, value)
    answer = find_answer(report)
    if answers.include? value
      true
    else
      false
    end
  end
end
