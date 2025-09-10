# frozen_string_literal: true

class FormField < ApplicationRecord
  # Associations
  belongs_to :form, inverse_of: :form_fields
  has_many :form_field_answer_options, dependent: :destroy
  has_many :report_form_field_answers, dependent: :destroy
  has_many :answer_options, through: :form_field_answer_options
  # rubocop:todo Rails/InverseOf
  has_many :childs, foreign_key: "parent_id", class_name: "FormField" # rubocop:todo Rails/HasManyOrHasOneDependent # rubocop:todo Rails/InverseOf
  # rubocop:enable Rails/InverseOf

  # Validations
  validates :question, presence: true

  # Enum
  enum status: { inactive: 0, active: 1 }

  # TODO: Rails 6.1 requires enums to be symbols
  # need additional refactoring in methods that call answer_type & answer_datatype to account for change to enum
  enum answer_type: { free_form_input_one_line: 0, free_form_input_paragraph: 1, multiple_choice_radio: 2, no_user_input: 3, multiple_choice_checkbox: 4, group_header: 5 }

  enum answer_datatype: { text_alphanumeric: 0, number_integer: 1, number_decimal: 2, date: 3 }

  rails_admin do
    # exclude_fields :answer_options
  end

  accepts_nested_attributes_for :form_field_answer_options

  default_scope { order(ordering: :desc) }

  # Methods
  def name
    question
  end

  def multiple_choice?
    answer_type ? answer_type.include?("multiple choice") : false
  end

  def html_id
    question.tr(" /#,')(.", "_").downcase
  end

  def html_input_type
    case answer_type

    when !parent_id.nil?
      :child

    when "free-form input - one line"
      parent_id.nil? ? :text : :child

    when "free-form input - paragraph"
      :textarea

    when "multiple choice - checkbox"
      :checkbox

    when "multiple choice - radio"
      :radio

    when "no user input"
      !childs.empty? ? :group_header : :label

    else
      :hidden
    end
  end

  # This one bellow should be removed and use
  # html_input_type
  def input_type
    case answer_type
    when "free-form input - one line"
      :text_field
    when "free-form input - paragraph"
      :text_area
    when "multiple choice - checkbox"
      :check_box
    when "multiple choice - radio"
      :radio_button
    when "no user input"
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
    answer&.response
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
    find_answer(report)
    answers.include?(value)
  end
end
