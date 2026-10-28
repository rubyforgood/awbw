require "base64"
require "zlib"

# Copies forms — settings, questions, answer options, and resources — from one
# environment to another (e.g. prod to staging) through a pasteable console line:
# `puts FormTransferService.console_script([ 12, 15 ])` (no ids: every form) in one
# console prints a `FormTransferService.import("…")` line for the other. Swapping
# `import` for `compare` lists how the target's copies differ, changing nothing.
#
# Copies are named for where they came from — "FROM PROD: <name>" — so they're
# never mistaken for the real thing; `version: 2` keeps a separate set ("FROM PROD V2: <name>").
# A later import of the same version refreshes that same copy to match the source — settings and question
# wording — and adds what it's missing; it never removes a question or option, so
# answers already given on the copy stay put. EventCopyService uses it for an
# event's linked forms.
class FormTransferService
  FORM_COLUMNS = %w[name role header sections anonymous].freeze
  UNCOPIED_FIELD_COLUMNS = %w[id form_id created_at updated_at created_by_id updated_by_id].freeze
  ENVIRONMENT_LABELS = { "production" => "PROD" }.freeze

  attr_reader :definitions, :form_changes, :warnings

  def self.console_script(form_ids = nil)
    forms = form_ids.present? ? Form.where(id: form_ids) : Form.all
    definitions = definitions(forms)
    payload = encode("environment" => Rails.env, "forms" => definitions)
    "FormTransferService.import(\"#{payload}\") # copy of #{definitions.size} #{"form".pluralize(definitions.size)} from #{Rails.env}"
  end

  def self.import(payload, version: nil)
    service = from_payload(payload, version:)
    Form.transaction { service.definitions.each_key { |id| service.form_for(id) } }
    service.report_changes
    nil
  end

  def self.compare(payload, version: nil)
    from_payload(payload, version:).report_differences
    nil
  end

  def self.from_payload(payload, version: nil)
    data = decode(payload)
    new(data["forms"], source_environment: data["environment"], version:)
  end

  # Source form id => its portable definition.
  def self.definitions(forms)
    forms.includes(form_fields: [ { form_field_answer_options: :answer_option }, { form_field_resources: :resource } ])
      .index_by(&:id).transform_values { |form| definition(form) }.as_json
  end

  def self.definition(form)
    {
      "attributes" => form.slice(*FORM_COLUMNS),
      "fields" => form.form_fields.sort_by { |field| [ field.position.to_i, field.id ] }.map do |field|
        {
          "id" => field.id,
          "attributes" => field.attributes.except(*UNCOPIED_FIELD_COLUMNS),
          "answer_options" => field.form_field_answer_options.sort_by(&:id).map(&:name),
          "resources" => field.form_field_resources.map { |link| link.slice("position").merge("resource" => link.resource.slice("id", "title")) }
        }
      end
    }
  end

  # A question is the same when its field identifier or, failing that, its wording matches.
  def self.take_matching_field(candidates, attributes)
    identifier = attributes["field_identifier"].presence
    match = (identifier && candidates.find { |field| field.field_identifier == identifier }) ||
      candidates.find { |field| field.name == attributes["name"] }
    candidates.delete(match)
  end

  def self.encode(data)
    Base64.strict_encode64(Zlib.gzip(JSON.generate(data)))
  end

  def self.decode(payload)
    JSON.parse(Zlib.gunzip(Base64.strict_decode64(payload)))
  end

  # A copy's name, prefixed with the environment it came from.
  # Version 1 (or none) is the plain "FROM PROD:" copy.
  def self.simulated_name(name, source_environment, version: nil)
    label = [ ENVIRONMENT_LABELS.fetch(source_environment, source_environment.upcase), ("V#{version}" if version.to_i > 1) ].compact.join(" ")
    "FROM #{label}: #{name}".truncate(Form::NAME_MAX_LENGTH)
  end

  # Definitions keyed by source form id (string keys, as in a decoded payload).
  def initialize(definitions, source_environment:, version: nil)
    @definitions = definitions
    @source_environment = source_environment
    @version = version
    @form_changes = {}
    @warnings = []
    @forms = {}
  end

  # This environment's copy of the source form, built or refreshed once per import.
  def form_for(source_id)
    @forms.fetch(source_id.to_s) do
      definition = @definitions[source_id.to_s]
      @forms[source_id.to_s] = definition && copy_form(definition)
    end
  end

  def existing_copy(definition)
    Form.order(:id).find_by(name: copy_name(definition.dig("attributes", "name")))
  end

  def report_changes
    form_changes.each do |form, change|
      verb = change[:created] ? "created" : "refreshed"
      counts = [ [ change[:questions], "question" ], [ change[:updated], "updated question" ], [ change[:options], "answer option" ] ]
        .map { |count, noun| "#{count} #{noun.pluralize(count)}" }.join(", ")
      puts "  + #{verb} form ##{form.id} \"#{form.name}\": #{counts}"
    end
    warnings.each { |warning| puts "  ! #{warning}" }
  end

  def report_differences
    @definitions.each_value do |definition|
      name = definition.dig("attributes", "name")
      form = existing_copy(definition)
      next puts("+ \"#{copy_name(name)}\" isn't here — import builds it") unless form

      differences = FormDefinitionDiff.new(definition, form).differences
      next puts("= Form ##{form.id} \"#{form.name}\" matches") if differences.empty?

      puts "~ Form ##{form.id} \"#{form.name}\" differs:"
      differences.each { |difference| puts "    #{difference}" }
    end
  end

  private

  def copy_name(name)
    self.class.simulated_name(name, @source_environment, version: @version)
  end

  def copy_form(definition)
    attributes = definition["attributes"].merge("name" => copy_name(definition.dig("attributes", "name")))
    form = existing_copy(definition)
    created = form.nil?
    form ||= Form.new
    form.update!(attributes)
    @form_changes[form] = { created: created, questions: 0, updated: 0, options: 0 }
    copy_questions(form, definition["fields"])
    form
  end

  # Questions on the copy that the source dropped stay, with their answers.
  def copy_questions(form, definitions)
    unmatched = form.form_fields.order(:position, :id).to_a
    fields = definitions.to_h do |data|
      attributes = data["attributes"].except("parent_id")
      field = self.class.take_matching_field(unmatched, data["attributes"])
      if field
        field.update!(attributes)
        @form_changes[form][:updated] += 1 if field.saved_changes?
      else
        field = form.form_fields.create!(attributes)
        @form_changes[form][:questions] += 1
      end
      add_missing_options(form, field, data)
      [ data["id"], field ]
    end
    definitions.each do |data|
      fields[data["id"]].update!(parent_id: fields[data["attributes"]["parent_id"]]&.id)
    end
  end

  def add_missing_options(form, field, data)
    missing = data["answer_options"] - field.form_field_answer_options.map(&:name)
    missing.each { |name| field.form_field_answer_options.create!(option_name: name) }
    @form_changes[form][:options] += missing.size
    data["resources"].each do |link|
      resource = find_resource(link["resource"])
      next if resource.nil? || field.form_field_resources.exists?(resource: resource)

      field.form_field_resources.create!(resource: resource, position: link["position"])
    end
  end

  def find_resource(ref)
    resource = Resource.find_by(title: ref["title"])
    @warnings |= [ "Resource \"#{ref["title"]}\" not found — skipped" ] unless resource
    resource
  end
end
