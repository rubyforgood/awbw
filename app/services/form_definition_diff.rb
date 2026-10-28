# Lists how a form differs from a FormTransferService definition — its settings,
# questions, answer options, and resources — so an admin can tell whether another
# environment's copy of a form matches the source. Questions pair up the way the
# copy matches them: field identifier, then wording.
class FormDefinitionDiff
  # The copy's name carries its source environment.
  FORM_SETTINGS = FormTransferService::FORM_COLUMNS - %w[name]
  # Ids differ across environments; parent links and order are compared through the matched questions.
  UNCOMPARED_FIELD_COLUMNS = %w[parent_id position].freeze
  SHOWN_VALUE_LENGTH = 40

  def initialize(definition, form)
    @definition = definition
    @form = form
  end

  def differences
    setting_differences + question_differences
  end

  private

  def setting_differences
    FORM_SETTINGS.filter_map do |column|
      value_difference(column, @definition["attributes"][column], @form.public_send(column).as_json)
    end
  end

  def question_differences
    unmatched = @form.form_fields.includes(:form_field_answer_options, form_field_resources: :resource).sort_by { |field| [ field.position.to_i, field.id ] }
    local_order = unmatched.dup
    pairs = @definition["fields"].to_h { |data| [ data["id"], FormTransferService.take_matching_field(unmatched, data["attributes"]) ] }
    differences = @definition["fields"].flat_map do |data|
      field = pairs[data["id"]]
      next [ "missing question \"#{data["attributes"]["name"]}\"" ] unless field

      field_differences(field, data, pairs).map { |difference| "\"#{field.name}\": #{difference}" }
    end
    differences += unmatched.map { |field| "extra question \"#{field.name}\"" }
    differences << "questions are in a different order" if pairs.values.compact != local_order - unmatched
    differences
  end

  def field_differences(field, data, pairs)
    attributes = data["attributes"].except(*UNCOMPARED_FIELD_COLUMNS)
    differences = attributes.filter_map { |column, value| value_difference(column, value, field.public_send(column).as_json) }
    differences << "follows a different question" if pairs[data["attributes"]["parent_id"]]&.id != field.parent_id
    differences + list_differences("options", data["answer_options"], field.form_field_answer_options.map(&:name)) +
      list_differences("resources", data["resources"].map { |link| link.dig("resource", "title") }, field.form_field_resources.map { |link| link.resource.title })
  end

  def value_difference(label, source, here)
    return if source == here

    shown = [ source, here ].map(&:inspect)
    return "#{label} differs" if shown.any? { |value| value.length > SHOWN_VALUE_LENGTH }

    "#{label}: source #{shown.first}, here #{shown.second}"
  end

  def list_differences(label, source, here)
    [
      ("missing #{label} #{(source - here).join(", ")}" if (source - here).any?),
      ("extra #{label} #{(here - source).join(", ")}" if (here - source).any?)
    ].compact
  end
end
