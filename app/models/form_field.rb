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

  # Field identifiers whose selectable options are sourced dynamically from
  # Sector records rather than the field's own stored answer options. The
  # submitted value for these is a Sector id (as a string).
  SERVICE_AREA_FIELD_IDENTIFIERS = %w[primary_service_area primary_service_area_single].freeze

  # Field identifiers whose selectable options are sourced dynamically from a
  # CategoryType's published categories. The submitted value is a Category id
  # (as a string). Maps the field identifier to its backing CategoryType name.
  DYNAMIC_FIELD_CATEGORY_TYPES = {
    "workshop_environments" => "WorkshopEnvironment",
    "client_life_experiences" => "StoryPopulation",
    "primary_age_group" => "AgeRange"
  }.freeze

  # The special free-text option label that lets a respondent supply their own
  # value; a chosen "Other" answer is stored as "Other" or "Other: <text>".
  OTHER_OPTION_PREFIX = "Other"

  # Fallback character ceilings applied when a free-form field has no explicit
  # max_characters set. This is a safety net against pathological submissions
  # (megabyte answers that bloat the DB and break admin/email rendering), not a
  # UX limit — the values are far above any realistic answer, and an explicit
  # per-field max_characters always wins, including when it is larger.
  DEFAULT_MAX_CHARACTERS = {
    "free_form_input_one_line" => 1_000,
    "free_form_input_paragraph" => 10_000
  }.freeze

  # Rough lower bound on characters a word consumes (average English word length
  # plus a separating space). Used to flag a max_characters that can't possibly
  # hold the min_words minimum, which would make the field impossible to submit.
  MIN_CHARS_PER_WORD = 6

  # Validations
  validates_presence_of :name
  # Keeps an over-long name as a friendly validation error instead of a
  # database ValueTooLong exception (the column is text, this is the UX cap).
  validates :name, length: { maximum: 1000 }
  validates :min_words, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_characters, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :max_characters_allows_min_words

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

  # Blocks an admin from saving a free-form field whose explicit max_characters
  # is too small to ever satisfy its min_words minimum (e.g. 250 words capped at
  # 1,000 characters) — otherwise the field could never be submitted. Compared
  # against the explicit max only; the generous default never conflicts.
  def max_characters_allows_min_words
    return unless free_form_text?
    return unless min_words.to_i.positive? && max_characters.to_i.positive?

    required = min_words * MIN_CHARS_PER_WORD
    return if max_characters >= required

    errors.add(:max_characters, "is too low for a #{min_words}-word minimum (allow at least #{required})")
  end

  # The character ceiling actually enforced for this field: the explicit
  # max_characters when set, otherwise the per-type default safety net. Returns
  # nil for non-free-form fields (no cap applies).
  def effective_max_characters
    return unless free_form_text?

    max_characters || DEFAULT_MAX_CHARACTERS[answer_type]
  end

  # Returns a validation error string when a submitted value exceeds the
  # effective maximum character count, or nil when it passes / does not apply.
  def max_characters_error(value)
    limit = effective_max_characters
    return unless limit
    return if value.blank?
    return if value.to_s.length <= limit

    "must be #{limit} #{"character".pluralize(limit)} or fewer"
  end

  # True when this field's selectable options come from Sector/Category data
  # rather than its own stored answer options. Dynamic fields never offer "Other".
  def dynamic_options?
    field_identifier.in?(SERVICE_AREA_FIELD_IDENTIFIERS) ||
      DYNAMIC_FIELD_CATEGORY_TYPES.key?(field_identifier)
  end

  # The set of values a submission may legitimately contain for this selectable
  # field — stored option names, or dynamic Sector/Category ids as strings —
  # exactly mirroring what the public form renders. nil for non-selectable
  # fields. This is the source of truth for both rendering and validation.
  def allowed_answer_values
    return unless selectable?

    values = if field_identifier.in?(SERVICE_AREA_FIELD_IDENTIFIERS)
      Sector.published.pluck(:id).map(&:to_s)
    elsif (type_name = DYNAMIC_FIELD_CATEGORY_TYPES[field_identifier])
      type = CategoryType.find_by(name: type_name)
      type ? type.categories.published.pluck(:id).map(&:to_s) : []
    else
      answer_options.pluck(:name)
    end

    values.to_set
  end

  # True when this field offers the free-text "Other" choice (stored fields only).
  def other_option?
    return false if dynamic_options?

    answer_options.any? { |option| option.name.to_s.strip.casecmp?(OTHER_OPTION_PREFIX) }
  end

  # True when a submitted value is a valid "Other" answer for a field that offers
  # the "Other" choice: bare "Other" or the "Other: <free text>" form.
  def other_answer?(value)
    return false unless other_option?

    value == OTHER_OPTION_PREFIX || value.start_with?("#{OTHER_OPTION_PREFIX}:")
  end

  # Returns a validation error string when a submitted selectable value is not
  # one of the field's offered options — guarding against tampered/forged
  # submissions — or nil when it passes / does not apply. Handles single and
  # multi-select, and allows "Other" / "Other: <text>" when the field offers it.
  # Blank values are left to the presence (required) check.
  def answer_inclusion_error(value)
    allowed = allowed_answer_values
    return unless allowed

    submitted = Array(value).map(&:to_s).reject(&:blank?)
    return if submitted.empty?
    return if submitted.all? { |v| allowed.include?(v) || other_answer?(v) }

    "has an invalid selection"
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
