class FormField < ApplicationRecord
  belongs_to :form, inverse_of: :form_fields
  has_many :form_field_answer_options, dependent: :destroy
  has_many :report_form_field_answers, dependent: :destroy
  has_many :form_answers, dependent: :nullify
  has_many :childs, foreign_key: "parent_id", class_name: "FormField"

  # has_many through
  has_many :answer_options, through: :form_field_answer_options

  # Answer types that collect free-form text, where a minimum word count applies
  FREE_FORM_TEXT_TYPES = %w[free_form_input_one_line free_form_input_paragraph].freeze

  # Validations
  validates_presence_of :name
  # Keeps an over-long name as a friendly validation error instead of a
  # database ValueTooLong exception (the column is text, this is the UX cap).
  validates :name, length: { maximum: 1000 }
  validates :min_words, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_characters, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # Enum
  enum :status, [ :inactive, :active ]
  enum :visibility, [ :always_ask, :scholarship_only, :logged_out_only, :answers_on_file ]

  enum :answer_type, [
    :free_form_input_one_line,
    :free_form_input_paragraph,
    :single_select_radio,
    :no_user_input,
    :multi_select_checkbox,
    :group_header,
    :single_select_dropdown
  ]

  enum :input_type, [
    :text_alphanumeric,
    :number_integer,
    :number_decimal,
    :date
  ]

  # Prefixed because :third/:first/etc. collide with Active Record finder methods
  enum :width, [ :full, :half, :third, :quarter ], prefix: true

  # Human-friendly labels for visibility, mirroring the form editor's options
  VISIBILITY_LABELS = {
    "always_ask" => "Always ask",
    "scholarship_only" => "Scholarship only",
    "logged_out_only" => "Logged out only",
    "answers_on_file" => "Answers on file"
  }.freeze

  # Human-friendly labels for answer types (radio/dropdown are "single select"
  # because only one option can be picked; checkbox allows several)
  ANSWER_TYPE_LABELS = {
    "group_header" => "Section header",
    "free_form_input_one_line" => "One line",
    "free_form_input_paragraph" => "Paragraph",
    "single_select_radio" => "Single select radio",
    "single_select_dropdown" => "Single select dropdown",
    "multi_select_checkbox" => "Multiple select checkbox",
    "no_user_input" => "Informational-only"
  }.freeze

  # Tailwind column spans within the 12-column form layout grid
  WIDTH_GRID_SPANS = {
    "full" => "md:col-span-12",
    "half" => "md:col-span-6",
    "third" => "md:col-span-4",
    "quarter" => "md:col-span-3"
  }.freeze

  # Nested attributes
  accepts_nested_attributes_for :form_field_answer_options, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:option_name].blank? }

  scope :published, -> { where(status: "active") }

  # Methods
  SELECTABLE_ANSWER_TYPES = %w[single_select_radio single_select_dropdown multi_select_checkbox].freeze

  def selectable?
    answer_type.in?(SELECTABLE_ANSWER_TYPES)
  end

  def html_id
    self.name.tr(" /#,')(.", "_").downcase
  end

  def grid_span_class
    WIDTH_GRID_SPANS.fetch(width, "md:col-span-12")
  end

  def answer_type_label
    ANSWER_TYPE_LABELS.fetch(answer_type, answer_type&.titleize)
  end

  def visibility_label
    VISIBILITY_LABELS.fetch(visibility, visibility&.humanize)
  end

  # True when the field is only asked under certain conditions, i.e. anything
  # other than "always ask". The forms preview highlights these.
  def conditional_visibility?
    !always_ask?
  end

  def free_form_text?
    FREE_FORM_TEXT_TYPES.include?(answer_type)
  end

  # Field identifiers (system-assigned by FormBuilderService) that collect an
  # email address, so a submitted value should be format-checked. The "*_type"
  # selector fields are deliberately excluded — this is an exact allowlist, not
  # a name-pattern match, so an unrelated field can't opt in by accident.
  EMAIL_FIELD_IDENTIFIERS = %w[primary_email confirm_email secondary_email payer_email].freeze

  def email_field?
    field_identifier.in?(EMAIL_FIELD_IDENTIFIERS)
  end

  def word_count(value)
    value.to_s.scan(/\S+/).size
  end

  # Returns a validation error string when a submitted value falls short of the
  # configured minimum word count, or nil when it passes / does not apply.
  # Blank values are left to the presence (required) check.
  def min_words_error(value)
    return unless free_form_text?
    return unless min_words.to_i.positive?
    return if value.blank?
    return if word_count(value) >= min_words

    "must be at least #{min_words} #{"word".pluralize(min_words)}"
  end

  # Returns a validation error string when a submitted value exceeds the
  # configured maximum character count, or nil when it passes / does not apply.
  def max_characters_error(value)
    return unless free_form_text?
    return unless max_characters.to_i.positive?
    return if value.blank?
    return if value.to_s.length <= max_characters

    "must be #{max_characters} #{"character".pluralize(max_characters)} or fewer"
  end

  def html_input_type
    return :child unless parent_id.nil?

    case answer_type
    when "free_form_input_one_line"
      :text
    when "free_form_input_paragraph"
      :textarea
    when "multi_select_checkbox"
      :checkbox
    when "single_select_radio"
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
    when "multi_select_checkbox"
      :check_box
    when "single_select_radio"
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
