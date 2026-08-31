module PersonServices
  # Write the two content-sharing answers onto the Person: whether their contributed
  # content is credited or anonymous, and which name format credits it. Both arrive as
  # the option label the question offered, so each maps back to its stored value; an
  # unanswered or unrecognized answer leaves the profile alone. Self-gating — a form
  # that doesn't ask the questions is a no-op — so a submission flow can call it
  # unconditionally, the way OrganizationServices::SyncProfile is called for an org.
  #
  # Shared by the public registration flow and the ticket-callout survey flow. The edit
  # lands on the Person, so AhoyTrackable logs it and the submission's "what this
  # submission changed" page picks it up; `changes` (attribute => [ from, to ]) reports
  # the same edits to a caller that tracks them itself.
  class SyncSharingPreferences
    # field_identifier => { option label => stored value }
    IDENTIFIER_VALUES = {
      "anonymous_contributions" => Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS,
      "display_name_preference" => Person::DISPLAY_NAME_PREFERENCE_LABELS
    }.freeze

    def self.call(person:, form:, form_params: {})
      new(person:, form:, form_params:).call
    end

    attr_reader :changes

    def initialize(person:, form:, form_params: {})
      @person = person
      @form = form
      @form_params = (form_params || {}).transform_keys(&:to_s)
      @changes = {}
    end

    def call
      IDENTIFIER_VALUES.each do |identifier, values|
        apply(identifier, values.invert[submitted_label(identifier)])
      end
      @person.save! if @person.changed?
      self
    end

    private

    # The label the person picked, or nil when this form doesn't ask the question.
    def submitted_label(identifier)
      field = @form.form_fields.find_by(field_identifier: identifier)
      field && @form_params[field.id.to_s]
    end

    def apply(identifier, new_value)
      return if new_value.nil?
      current = @person.public_send(identifier)
      return if current == new_value
      @changes[identifier.to_sym] = [ current, new_value ]
      @person.public_send("#{identifier}=", new_value)
    end
  end
end
