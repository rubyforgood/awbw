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

  # Answer types that display text only and never collect a response — so a
  # "required" flag is meaningless for them (nothing to fill in).
  NON_INPUT_ANSWER_TYPES = %w[no_user_input group_header].freeze

  # Multi-select "additional sectors" field identifiers. "additional_sectors" is
  # the canonical name new forms are built with; the older "primary_sector" name
  # (a misnomer — it was always the multi-select additional field) and the legacy
  # "service area" name are both still accepted so existing form data keeps
  # resolving.
  ADDITIONAL_SECTOR_FIELD_IDENTIFIERS = %w[additional_sectors primary_sector primary_service_area].freeze

  # Single-select "primary sector" field identifiers (current + legacy). Unlike
  # the multi-select "additional" field, these omit the catch-all "Other" sector
  # — a respondent's primary sector must be a concrete sector.
  PRIMARY_SECTOR_FIELD_IDENTIFIERS = %w[primary_sector_single primary_service_area_single].freeze

  # Field identifiers whose selectable options are sourced dynamically from
  # Sector records rather than the field's own stored answer options. The
  # submitted value for these is a Sector id (as a string).
  SECTOR_FIELD_IDENTIFIERS = (ADDITIONAL_SECTOR_FIELD_IDENTIFIERS + PRIMARY_SECTOR_FIELD_IDENTIFIERS).freeze

  # Field identifiers whose selectable options are sourced dynamically from a
  # CategoryType's published categories. The submitted value is a Category id
  # (as a string). Maps the field identifier to its backing CategoryType name.
  # Both the "primary" and "additional" age group fields are backed by the
  # published AgeRange categories. Unlike the sector fields, age groups have no
  # catch-all option — the additional sector field keeps "Other", but neither age
  # field offers one.
  DYNAMIC_FIELD_CATEGORY_TYPES = {
    "primary_age_group" => "AgeRange",
    "additional_age_group" => "AgeRange"
  }.freeze

  # The payment-method field. Its answer options ("Credit card (now)", etc.) are
  # wired to Stripe charge logic in the controllers, so they must not be edited
  # casually from the form builder — the editor shows them read-only unless the
  # admin override is present.
  PAYMENT_METHOD_FIELD_IDENTIFIER = "payment_method"

  # The generic free-text option label that lets a respondent supply their own
  # value; a chosen "Other" answer is stored as "Other" or "Other: <text>".
  OTHER_OPTION_PREFIX = "Other"

  # Selectable option labels that reveal a free-text "please specify" box when
  # chosen, each mapped to that box's placeholder. A chosen answer is stored as
  # "<label>: <typed text>" (or the bare label when nothing is typed), so the
  # server needs no extra params. "Other" is the generic catch-all; the rest
  # capture a specific named source for "how did you hear about us" questions.
  SPECIFY_OPTION_PLACEHOLDERS = {
    OTHER_OPTION_PREFIX => "Please specify",
    "Work(ed) at an agency that has/had an AWBW program" => "Please specify organization",
    "Word of Mouth" => "Please list the name of the person",
    "Foundation/Funder" => "Please list the name of the foundation/funder"
  }.freeze

  # Specify options scoped to a single field by its field_identifier, rather than
  # to an option label everywhere it appears (SPECIFY_OPTION_PLACEHOLDERS). The
  # CE-interest question's "Yes" reveals a "How many CE hours?" box that only
  # makes sense there — a bare "Yes" anywhere else must stay a plain choice. The
  # typed value folds into the answer as "Yes: <hours>", which the registration
  # service parses onto EventRegistration#ce_hours_requested. The identifier
  # matches EventRegistrationServices::PublicRegistration::CE_CREDIT_INTEREST_IDENTIFIER.
  FIELD_SPECIFY_OPTION_PLACEHOLDERS = {
    "ce_credit_interest" => { "Yes" => "How many CE hours?" }
  }.freeze

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
  # A field_identifier wires a field to backend logic (Stripe, service areas,
  # email checks, etc.), so the same identifier must not appear twice on one form
  # or that logic would target an ambiguous field. Ordinary fields carry no
  # identifier, so blanks are exempt — any number of them may coexist.
  validates :field_identifier, uniqueness: { scope: :form_id }, allow_blank: true
  validates :min_words, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :max_characters, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validate :max_characters_allows_min_words
  validate :non_input_types_cannot_be_required

  # New fields submitted without a position (e.g. added in the form editor and
  # not dragged) would otherwise save with a nil position and sort to the top of
  # the list. Append them to the bottom instead. Dragged fields arrive with an
  # explicit position and are left untouched.
  before_validation :append_to_bottom, on: :create, if: -> { position.blank? }

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

  # True for fields whose answer options are tied to backend logic (currently the
  # payment-method field's Stripe wiring) and so should be shown read-only in the
  # form builder rather than freely edited.
  def fixed_options?
    field_identifier == PAYMENT_METHOD_FIELD_IDENTIFIER
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

  # False for display-only types (informational text, section headers) that
  # never collect an answer; true for every field a respondent fills in.
  def collects_input?
    NON_INPUT_ANSWER_TYPES.exclude?(answer_type)
  end

  # Field identifiers (system-assigned by FormBuilderService) that collect an
  # email address, so a submitted value should be format-checked. The "*_type"
  # selector fields are deliberately excluded — this is an exact allowlist, not
  # a name-pattern match, so an unrelated field can't opt in by accident.
  EMAIL_FIELD_IDENTIFIERS = %w[primary_email confirm_email secondary_email payer_email].freeze

  def email_field?
    field_identifier.in?(EMAIL_FIELD_IDENTIFIERS)
  end

  # Counts whitespace-separated tokens. Uses the Unicode-aware [[:space:]] class
  # rather than \S, which is ASCII-only — pasted answers (Word, Google Docs, web
  # pages) routinely carry non-breaking (U+00A0) and other Unicode spaces that \S
  # treats as word characters, collapsing a real answer into one "word" and
  # wrongly tripping the minimum.
  def word_count(value)
    value.to_s.scan(/[^[:space:]]+/).size
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

  # Display-only fields (informational text, section headers) have nothing to
  # fill in, so they can't be marked required.
  def non_input_types_cannot_be_required
    return if collects_input?
    return unless required?

    errors.add(:required, "is not available for #{answer_type_label.downcase} fields")
  end

  # Places a positionless new field after the current last field on its form, so
  # newly added fields land at the bottom of the editor list rather than the top.
  def append_to_bottom
    self.position = (form&.form_fields&.maximum(:position) || 0) + 1
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
    field_identifier.in?(SECTOR_FIELD_IDENTIFIERS) ||
      DYNAMIC_FIELD_CATEGORY_TYPES.key?(field_identifier)
  end

  # The set of values a submission may legitimately contain for this selectable
  # field — stored option names, or dynamic Sector/Category ids as strings —
  # exactly mirroring what the public form renders. nil for non-selectable
  # fields. This is the source of truth for both rendering and validation.
  def allowed_answer_values
    return unless selectable?

    values = if field_identifier.in?(SECTOR_FIELD_IDENTIFIERS)
      sector_options.pluck(:id).map(&:to_s)
    elsif DYNAMIC_FIELD_CATEGORY_TYPES.key?(field_identifier)
      dynamic_categories.pluck(:id).map(&:to_s)
    else
      answer_options.pluck(:name)
    end

    values.to_set
  end

  # The published Sector records a sector-backed field offers, in name order. The
  # single-select "primary" field omits the catch-all "Other" sector; the
  # multi-select "additional" field includes it. Source of truth shared by the
  # public form's rendering and submission validation.
  def sector_options
    scope = Sector.published.order(:name)
    field_identifier.in?(PRIMARY_SECTOR_FIELD_IDENTIFIERS) ? scope.excluding_other : scope
  end

  # The published Category records a category-backed dynamic field offers, in
  # position/name order. Empty when the backing CategoryType is missing. Source of
  # truth shared by the public form's rendering and submission validation.
  def dynamic_categories
    type = CategoryType.find_by(name: DYNAMIC_FIELD_CATEGORY_TYPES[field_identifier])
    return Category.none unless type

    type.categories.published.order(:position, :name)
  end

  # The "please specify" placeholder for an option label, or nil when the option
  # does not reveal a free-text box. Matched case- and whitespace-insensitively
  # against SPECIFY_OPTION_PLACEHOLDERS, then (when a field_identifier is given)
  # against that field's FIELD_SPECIFY_OPTION_PLACEHOLDERS, which wins.
  def self.specify_placeholder_for(label, field_identifier = nil)
    normalized = label.to_s.strip
    return if normalized.blank?

    field_scoped = FIELD_SPECIFY_OPTION_PLACEHOLDERS[field_identifier]&.find { |key, _| key.casecmp?(normalized) }&.last
    field_scoped || SPECIFY_OPTION_PLACEHOLDERS.find { |key, _| key.casecmp?(normalized) }&.last
  end

  # True when an option label reveals a free-text "please specify" box, optionally
  # scoped to a field via its field_identifier.
  def self.specify_option?(label, field_identifier = nil)
    specify_placeholder_for(label, field_identifier).present?
  end

  # True when an option label is the generic free-text "Other" choice. Unlike
  # the named specify options (whose bare label still carries meaning), a bare
  # "Other" is useless, so dropdowns — which can't collect the free text —
  # strip it entirely.
  def self.other_option?(label)
    label.to_s.strip.casecmp?(OTHER_OPTION_PREFIX)
  end

  # The labels of this field's offered options that reveal a free-text box
  # (e.g. "Other", "Word of Mouth"). Dynamic sector/category fields offer one
  # only when their option set includes a catch-all "Other" (the published "Other"
  # Sector, or an "Other"-named Category) — the multi-select "additional sectors"
  # field is the common case. The single-select "primary" fields drop "Other" from
  # their options, so they expose no specify option.
  def specify_option_labels
    option_names = dynamic_options? ? dynamic_option_names : answer_options.map(&:name)
    option_names.select { |name| FormField.specify_option?(name, field_identifier) }
  end

  # The names of this field's dynamically-sourced options (Sector or Category),
  # mirroring what the public form renders and what allowed_answer_values keys
  # off. Used to detect a catch-all "Other" option on a dynamic field. Empty for
  # non-dynamic fields.
  def dynamic_option_names
    if field_identifier.in?(SECTOR_FIELD_IDENTIFIERS)
      sector_options.pluck(:name)
    elsif DYNAMIC_FIELD_CATEGORY_TYPES.key?(field_identifier)
      dynamic_categories.pluck(:name)
    else
      []
    end
  end

  # True when a submitted value is a valid "specify" answer for one of this
  # field's specify options: the bare label or its "<label>: <free text>" form.
  def specify_answer?(value)
    specify_option_labels.any? do |label|
      value == label || value.start_with?("#{label}:")
    end
  end

  # Returns a validation error string when a submitted selectable value is not
  # one of the field's offered options — guarding against tampered/forged
  # submissions — or nil when it passes / does not apply. Handles single and
  # multi-select, and allows a "specify" option's "<label>: <text>" free-text
  # form when the field offers it. Blank values are left to the presence check.
  def answer_inclusion_error(value)
    allowed = allowed_answer_values
    return unless allowed

    submitted = Array(value).map(&:to_s).reject(&:blank?)
    return if submitted.empty?
    return if submitted.all? { |v| allowed.include?(v) || specify_answer?(v) }

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
