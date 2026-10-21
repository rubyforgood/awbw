require "base64"
require "zlib"

# Copies an event and its settings — ticket callouts (with their forms and
# resources), linked forms, staff, tags, location, rich text, and images — onto a
# new unpublished event. Every date travels as days relative to the event's start
# (plus its wall-clock time in Event::PROGRAM_ZONE), so the copy lands on a new
# start date with its deadlines and drip dates shifted to match.
#
# The copy goes through a plain-JSON blueprint, so it can also cross environments:
# `puts EventCopyService.console_script(event)` in one console prints a line to
# paste into another, where linked records are matched by name/email, not id. That
# payload also carries each linked form's questions: a form the target lacks is
# built there, and a form it has gains only the questions and options it's missing,
# so its id — and every submission already on it — stays put.
class EventCopyService
  BLUEPRINT_VERSION = 1
  COPY_TITLE_PREFIX = "Copy of ".freeze
  MATCH_MODES = %i[id natural].freeze
  ASSET_TYPES = %w[PrimaryAsset GalleryAsset].freeze
  ASSET_URL_TTL = 1.day

  DATETIME_COLUMNS = %w[start_date end_date registration_close_date ce_payment_due_deadline payment_due_deadline].freeze
  DATE_COLUMNS = %w[ce_hours_request_deadline completion_deadline].freeze
  UNCOPIED_COLUMNS = %w[id created_at updated_at created_by_id updated_by_id location_id affiliations_reconciled_at].freeze
  # A copy starts as a draft: hidden from the public and without the source's unique abbreviation.
  DRAFT_ATTRIBUTES = { "published" => false, "featured" => false, "publicly_visible" => false,
                       "publicly_featured" => false, "abbreviation" => nil }.freeze
  CALLOUT_COLUMNS = %w[builtin_key callout_type title subtitle description icon_class color_class hidden
                       payment_access_gated ce_payment_access_gated attended_gated].freeze
  RICH_TEXT_FIELDS = %w[rhino_header rhino_description].freeze
  FORM_COLUMNS = %w[name role header sections].freeze
  UNCOPIED_FIELD_COLUMNS = %w[id form_id created_at updated_at created_by_id updated_by_id].freeze

  attr_reader :warnings, :form_changes

  def self.copy(event, start_on:, title: nil)
    for_event(event).call(start_on: start_on, title: title)
  end

  # Exposed so a caller can read #warnings after the copy.
  def self.for_event(event)
    new(blueprint(event))
  end

  def self.blueprint(event, form_definitions: false)
    start_on = event.starts_on
    {
      "version" => BLUEPRINT_VERSION,
      "source" => { "id" => event.id, "title" => event.title, "start_on" => start_on.iso8601 },
      "attributes" => event.attributes.except(*UNCOPIED_COLUMNS, *DATETIME_COLUMNS, *DATE_COLUMNS),
      "dates" => (DATETIME_COLUMNS + DATE_COLUMNS).index_with { |column| offset(event[column], start_on) },
      "rich_text" => RICH_TEXT_FIELDS.index_with { |field| event.public_send(field)&.body&.to_html },
      "location" => event.location&.slice("id", "city", "state", "country"),
      "event_forms" => event.event_forms.includes(:form).map { |link| { "role" => link.role, "form" => form_ref(link.form) } },
      "categories" => event.categorizable_items.includes(category: :category_type).map do |item|
        { "id" => item.category_id, "name" => item.category.name, "type" => item.category.category_type&.name, "is_primary" => item.is_primary }
      end,
      "sectors" => event.sectorable_items.includes(:sector).map do |item|
        { "id" => item.sector_id, "name" => item.sector.name, "is_primary" => item.is_primary, "is_leader" => item.is_leader }
      end,
      "staff" => event.event_staffs.includes(:person).map do |staff|
        staff.slice("title", "expected_to_attend", "bio").merge("person" => staff.person.slice("id", "email", "first_name", "last_name"))
      end,
      "callouts" => event.registration_ticket_callouts.includes(registration_ticket_callout_forms: :form, registration_ticket_callout_resources: :resource).map do |callout|
        callout.slice(*CALLOUT_COLUMNS).merge(
          "display_from" => offset(callout.display_from, start_on),
          "forms" => callout.registration_ticket_callout_forms.map do |link|
            { "form" => form_ref(link.form), "display_from" => offset(link.display_from, start_on) }
          end,
          "resources" => callout.registration_ticket_callout_resources.map do |link|
            link.slice("subtitle", "page_content").merge("resource" => link.resource.slice("id", "title"))
          end
        )
      end,
      "assets" => event.assets.where(type: ASSET_TYPES).order(:id).select { |asset| asset.file.attached? }.map do |asset|
        { "type" => asset.type, "title" => asset.title, "blob_id" => asset.file.blob.id, "url" => asset_url(asset) }
      end,
      "form_definitions" => (form_definitions ? linked_forms(event).index_by(&:id).transform_values { |form| form_definition(form) } : {})
    }.as_json
  end

  # One pasteable line for another environment's Rails console.
  def self.console_script(event)
    payload = Base64.strict_encode64(Zlib.gzip(JSON.generate(blueprint(event, form_definitions: true))))
    "EventCopyService.import(\"#{payload}\") # copy of event ##{event.id} \"#{event.title}\" (#{event.starts_on})"
  end

  # Console entry point for a console_script payload: matches linked records by
  # name/email, prints what it couldn't link, and returns the new event.
  def self.import(payload, start_on: nil, title: nil)
    service = new(JSON.parse(Zlib.gunzip(Base64.strict_decode64(payload))), match_by: :natural)
    event = service.call(start_on: start_on, title: title)
    puts "Created event ##{event.id} \"#{event.title}\" starting #{event.starts_on} (unpublished)."
    service.form_changes.each do |form, change|
      next unless change[:created] || change[:questions].positive? || change[:options].positive?

      verb = change[:created] ? "created" : "added to"
      counts = "#{change[:questions]} #{"question".pluralize(change[:questions])}, #{change[:options]} answer #{"option".pluralize(change[:options])}"
      puts "  + #{verb} form ##{form.id} \"#{form.name}\": #{counts}"
    end
    service.warnings.each { |warning| puts "  ! #{warning}" }
    event
  end

  def self.offset(value, start_on)
    return if value.nil? || start_on.nil?
    return { "days" => (value - start_on).to_i } if value.is_a?(Date)

    local = value.in_time_zone(Event::PROGRAM_ZONE)
    { "days" => (local.to_date - start_on).to_i, "time" => local.strftime("%H:%M:%S") }
  end

  def self.form_ref(form)
    form.slice("id", "name", "role")
  end

  def self.linked_forms(event)
    form_ids = event.event_forms.pluck(:form_id) +
      RegistrationTicketCalloutForm.joins(:registration_ticket_callout)
        .where(registration_ticket_callouts: { event_id: event.id }).pluck(:form_id)
    Form.where(id: form_ids.uniq).includes(form_fields: [ { form_field_answer_options: :answer_option }, { form_field_resources: :resource } ])
  end

  def self.form_definition(form)
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

  def self.asset_url(asset)
    asset.file.url(expires_in: ASSET_URL_TTL)
  rescue ArgumentError
    nil
  end

  private_class_method :offset, :form_ref, :linked_forms, :form_definition, :asset_url

  def initialize(blueprint, match_by: :id)
    raise ArgumentError, "match_by must be one of #{MATCH_MODES}" unless MATCH_MODES.include?(match_by)
    raise ArgumentError, "unsupported blueprint version #{blueprint["version"]}" unless blueprint["version"] == BLUEPRINT_VERSION

    @blueprint = blueprint
    @match_by = match_by
    @warnings = []
    @form_changes = {}
    @forms = {}
  end

  def call(start_on: nil, title: nil)
    @start_on = (start_on.presence || @blueprint.dig("source", "start_on")).to_date
    event = Event.transaction do
      Event.create!(event_attributes(title)).tap do |created|
        copy_event_forms(created)
        copy_tags(created)
        copy_staff(created)
        copy_callouts(created)
        BuiltinCallouts.seed(created)
      end
    end
    copy_assets(event)
    event
  end

  private

  def event_attributes(title)
    @blueprint["attributes"]
      .merge(DRAFT_ATTRIBUTES)
      .merge(@blueprint["dates"].transform_values { |offset| shift(offset) })
      .merge(@blueprint["rich_text"].compact)
      .merge("title" => title.presence || @blueprint["attributes"]["title"], "location" => find_location)
  end

  def shift(offset)
    return if offset.nil?

    date = @start_on + offset["days"]
    return date unless offset["time"]

    ActiveSupport::TimeZone[Event::PROGRAM_ZONE].parse("#{date.iso8601} #{offset["time"]}")
  end

  def copy_event_forms(event)
    @blueprint["event_forms"].each do |link|
      form = find_form(link["form"])
      next unless form

      warn_public_link_retired(form)
      event.event_forms.create!(form: form, role: link["role"])
    end
  end

  # EventForm unpublishes a published form the moment it's linked, taking its
  # public /f/:slug link offline — surface that so whoever ran the import knows
  # a live form went dark.
  def warn_public_link_retired(form)
    return unless form.published?

    add_warning("Form \"#{form.name}\" was published — linking it to the copy took its public link offline")
  end

  def copy_tags(event)
    @blueprint["categories"].each do |data|
      category = find_category(data)
      event.categorizable_items.create!(category: category, is_primary: data["is_primary"]) if category
    end
    @blueprint["sectors"].each do |data|
      sector = resolve(Sector, data["id"], "Sector \"#{data["name"]}\"") { Sector.find_by(name: data["name"]) }
      event.sectorable_items.create!(sector: sector, is_primary: data["is_primary"], is_leader: data["is_leader"]) if sector
    end
  end

  def copy_staff(event)
    @blueprint["staff"].each do |data|
      person = find_person(data["person"])
      event.event_staffs.create!(data.slice("title", "expected_to_attend", "bio").merge("person" => person)) if person
    end
  end

  def copy_callouts(event)
    @blueprint["callouts"].each do |data|
      callout = event.registration_ticket_callouts.create!(
        data.slice(*CALLOUT_COLUMNS).merge("display_from" => shift(data["display_from"]))
      )
      data["forms"].each do |link|
        form = find_form(link["form"])
        callout.registration_ticket_callout_forms.create!(form: form, display_from: shift(link["display_from"])) if form
      end
      data["resources"].each do |link|
        resource = find_resource(link["resource"])
        callout.registration_ticket_callout_resources.create!(link.slice("subtitle", "page_content").merge("resource" => resource)) if resource
      end
    end
  end

  # Each copy gets its own blob: Asset purges its file on destroy, so a shared
  # blob would vanish from the copy when the source's image is removed.
  def copy_assets(event)
    @blueprint["assets"].each do |data|
      @match_by == :id ? duplicate_blob(event, data) : download_asset(event, data)
    end
  end

  def duplicate_blob(event, data)
    blob = ActiveStorage::Blob.find_by(id: data["blob_id"])
    return add_warning("#{data["type"]} image (blob #{data["blob_id"]}) not found") unless blob

    blob.open do |file|
      asset = event.assets.build(type: data["type"], title: data["title"])
      asset.file.attach(io: file, filename: blob.filename.to_s, content_type: blob.content_type)
      asset.save!
    end
  rescue ActiveStorage::Error, ActiveRecord::RecordInvalid => e
    add_warning("#{data["type"]} image not copied: #{e.message}")
  end

  def download_asset(event, data)
    return add_warning("#{data["type"]} image has no download URL") if data["url"].blank?

    AssetUrlImporter.new(url: data["url"], owner: event, type: data["type"], title: data["title"]).call
  rescue AssetUrlImporter::Error, ActiveRecord::RecordInvalid => e
    add_warning("#{data["type"]} image not copied: #{e.message}")
  end

  def find_location
    data = @blueprint["location"]
    return unless data

    resolve(Location, data["id"], "Location #{data.values_at("city", "state").compact.join(", ")}") do
      Location.find_or_create_by!(data.slice("city", "state", "country"))
    end
  end

  # Memoized by source id so a form linked in several places is matched (or
  # built) once.
  def find_form(ref)
    @forms.fetch(ref["id"]) do
      @forms[ref["id"]] = resolve(Form, ref["id"], "Form \"#{ref["name"]}\"") { portable_form(ref) }
    end
  end

  def portable_form(ref)
    form = matching_form(ref)
    definition = @blueprint.dig("form_definitions", ref["id"].to_s)
    return form unless definition

    created = form.nil?
    form ||= Form.create!(definition["attributes"])
    @form_changes[form] = { created: created, questions: 0, options: 0 }
    add_missing_questions(form, definition["fields"])
    form
  end

  # Each survey role belongs to one form, so the target's form for that role stands in.
  def matching_form(ref)
    named = Form.order(:id).find_by(name: ref["name"], role: ref["role"]) || Form.order(:id).find_by(name: ref["name"])
    return named if named

    Form.survey(ref["role"]) if Form::SURVEY_ROLES.include?(ref["role"])
  end

  # Additive only: questions already on the form keep their id, wording, and
  # answers; a question is the same when its field identifier or, failing that,
  # its wording matches.
  def add_missing_questions(form, definitions)
    unmatched = form.form_fields.order(:position, :id).to_a
    added = []
    fields = definitions.to_h do |data|
      field = take_matching_field(unmatched, data["attributes"])
      unless field
        field = form.form_fields.create!(data["attributes"].except("parent_id"))
        added << data
      end
      add_missing_options(form, field, data)
      [ data["id"], field ]
    end
    added.each do |data|
      parent = fields[data["attributes"]["parent_id"]]
      fields[data["id"]].update!(parent_id: parent.id) if parent
    end
    @form_changes[form][:questions] += added.size
  end

  def take_matching_field(candidates, attributes)
    identifier = attributes["field_identifier"].presence
    match = (identifier && candidates.find { |field| field.field_identifier == identifier }) ||
      candidates.find { |field| field.name == attributes["name"] }
    candidates.delete(match)
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
    resolve(Resource, ref["id"], "Resource \"#{ref["title"]}\"") { Resource.find_by(title: ref["title"]) }
  end

  def find_category(data)
    resolve(Category, data["id"], "Category \"#{data["name"]}\"") do
      Category.includes(:category_type).where(name: data["name"]).find { |category| category.category_type&.name == data["type"] }
    end
  end

  def find_person(ref)
    label = "Staff #{ref.values_at("first_name", "last_name").compact.join(" ")}"
    resolve(Person, ref["id"], label) do
      (ref["email"].presence && Person.find_by(email: ref["email"])) ||
        Person.find_by(first_name: ref["first_name"], last_name: ref["last_name"])
    end
  end

  # Same-database copies link the very records the source used; cross-environment
  # copies look them up by their natural key (the block). Misses are skipped and
  # reported rather than failing the whole copy.
  def resolve(model, id, label)
    record = @match_by == :id ? model.find_by(id: id) : yield
    add_warning("#{label} not found — skipped") unless record
    record
  end

  # One line per problem: the same missing record is routinely referenced from
  # several callouts, questions, or forms.
  def add_warning(message)
    @warnings |= [ message ]
  end
end
