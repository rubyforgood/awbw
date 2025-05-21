class FormField < ApplicationRecord
  # Associations
  belongs_to :form, inverse_of: :form_fields
  has_many :form_field_answer_options, dependent: :destroy
  has_many :report_form_field_answers, dependent: :destroy
  has_many :answer_options, through: :form_field_answer_options
  has_many :childs, foreign_key: "parent_id", class_name: "FormField"

  # Validations
  validates_presence_of :question

  # Enum
  enum status: [:inactive, :active]

  enum answer_type: ['free-form input - one line', 'free-form input - paragraph',
                     'multiple choice - radio', 'no user input',
                     'multiple choice - checkbox', 'group-header']

  enum answer_datatype: ['text (alphanumeric)', 'number (integer)', 'number (decimal)',
                         'date']

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
    answer_type ? answer_type.include?('multiple choice') : false
  end

  def html_id
    self.question.tr(" /#,')(.","_").downcase
  end

  def html_input_type
    case answer_type

    when !self.parent_id.nil?
      :child

    when 'free-form input - one line'
      self.parent_id.nil? ? :text : :child

    when 'free-form input - paragraph'
      :textarea

    when 'multiple choice - checkbox'
      :checkbox

    when 'multiple choice - radio'
      :radio

    when 'no user input'
      !self.childs.empty? ? :group_header : :label

    else
      :hidden
    end
  end

  # This one bellow should be removed and use 
  # html_input_type
  def input_type
    case answer_type
    when 'free-form input - one line'
      :text_field
    when 'free-form input - paragraph'
      :text_area
    when 'multiple choice - checkbox'
      :check_box
    when 'multiple choice - radio'
      :radio_button
    when 'no user input'
      :label
    else
      :hidden_field
    end
  end

  def find_answer(report)
    return if report.nil?
    report.report_form_field_answers.select{|fa| fa.form_field == self}.first
  end

  def answer report
    answer = find_answer(report)
    answer.response unless answer.nil?
  end

  def checked report, value
    answer = find_answer(report)

    if answer.nil?
      false
    else
      answer.response == value
    end
  end

  def selected report, value
    answer = find_answer(report)
    if answers.include? value
      true
    else
      false
    end
  end
end
