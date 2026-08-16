# Validates submitted answer values against each form field's configuration:
# presence (required), integer/email format, the per-field min-words /
# max-characters settings, and — for selectable fields — that the value is one
# of the field's offered options (guarding against forged submissions). Returns
# a hash of { field_id => error_message } so results from multiple forms (e.g.
# registration + scholarship) can be merged.
#
# Group headers are skipped here; any other field-specific exclusions (e.g.
# bulk payment's nested attendees) are the caller's responsibility — pass only
# the fields you want validated.
class FormAnswerValidator
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s]+\z/
  WHOLE_NUMBER_FORMAT = /\A\d+\z/

  def self.call(fields, form_params)
    new(fields, form_params).call
  end

  def initialize(fields, form_params)
    @fields = fields
    @form_params = form_params
  end

  def call
    @fields.each_with_object({}) do |field, errors|
      next if field.group_header?

      error = error_for(field, @form_params[field.id.to_s])
      errors[field.id] = error if error
    end
  end

  private

  def error_for(field, value)
    return "can't be blank" if field.required && blank_answer?(value)
    return if value.blank?

    # A file upload arrives as a signed blob id (or an uploaded file), not text —
    # the word/character/format/inclusion checks below don't apply. Its content
    # type is enforced by Asset when the file is attached during submission.
    return if field.file_upload?

    if field.number_integer? && value.to_s !~ WHOLE_NUMBER_FORMAT
      "must be a whole number"
    elsif field.email_field? && value.to_s !~ EMAIL_FORMAT
      "must be a valid email address"
    else
      field.min_words_error(value) || field.max_characters_error(value) || field.answer_inclusion_error(value)
    end
  end

  def blank_answer?(value)
    value.blank? || (value.is_a?(Array) && value.reject(&:blank?).empty?)
  end
end
