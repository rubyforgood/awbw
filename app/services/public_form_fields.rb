# The questions a standalone public form shows its respondent, and the account
# details that prefill them. A logged-in respondent skips the "Logged out only"
# questions their profile already answers — except, on a form set to anonymous, the
# identity questions, which stay visible and prefilled so clearing them is how the
# respondent stays anonymous.
class PublicFormFields
  IDENTITY_PREFILLS = {
    "first_name" => :first_name,
    "last_name" => :last_name,
    "primary_email" => :preferred_email,
    "confirm_email" => :preferred_email
  }.freeze

  # Identity answers from the person for whichever of these fields ask for them.
  def self.identity_prefill(fields, person)
    return {} unless person

    fields.select { |field| IDENTITY_PREFILLS.key?(field.field_identifier) }
          .to_h { |field| [ field.id, person.public_send(IDENTITY_PREFILLS[field.field_identifier]) ] }
  end

  def initialize(form:, person:)
    @form = form
    @person = person
  end

  def visible
    @visible ||= begin
      fields = @form.form_fields.reorder(position: :asc).to_a
      hidden = fields.select { |field| skipped?(field) }
      fields - hidden - emptied_headers(fields, hidden)
    end
  end

  def prefill_values
    self.class.identity_prefill(visible, @person)
  end

  private

  def skipped?(field)
    return false unless @person && field.logged_out_only? && !field.group_header?
    return false if anonymous_identity_field?(field)

    field.field_identifier.in?(known_identifiers)
  end

  def anonymous_identity_field?(field)
    @form.anonymous? && IDENTITY_PREFILLS.key?(field.field_identifier)
  end

  # A "Logged out only" section header goes too once every question under it is skipped.
  def emptied_headers(fields, hidden)
    return [] if hidden.empty?

    fields.select do |field|
      next false unless field.group_header? && field.logged_out_only? && field.section.present?

      questions = fields.select { |other| other.section == field.section && !other.group_header? }
      questions.any? && (questions - hidden).empty?
    end
  end

  def known_identifiers
    @known_identifiers ||= PersonServices::KnownFieldIdentifiers.call(@person)
  end
end
