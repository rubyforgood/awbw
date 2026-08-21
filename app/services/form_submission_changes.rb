# Reconstructs everything one form submission changed across records, read back
# from the Ahoy lifecycle events each write already emits (stamped with the
# submission id by the registration flow). Groups the changes by the record they
# happened to and labels each with what actually happened to it — added, removed,
# replaced, or filled (a blank) — for the admin "what this submission changed" page.
class FormSubmissionChanges
  # The records whose changes are worth surfacing. Bookkeeping rows a submission
  # also touches (the submission, its answers, the registration link) are noise here.
  RELEVANT_TYPES = %w[Person Organization Address ContactMethod Affiliation SectorableItem CategorizableItem].freeze
  GROUP_ORDER = %w[Person Organization Affiliation].freeze
  IGNORED_ATTRIBUTES = %w[id created_at updated_at slug locality].freeze

  Change = Struct.new(:outcome, :label, :value, :previous_value, keyword_init: true)
  Group = Struct.new(:record_type, :title, :changes, keyword_init: true)

  def initialize(form_submission)
    @form_submission = form_submission
  end

  def groups
    relevant_events
      .group_by { |event| owner_key(event) }
      .filter_map { |(type, id), events| build_group(type, id, events) }
      .reject { |group| group.changes.empty? }
      .sort_by { |group| [ GROUP_ORDER.index(group.record_type) || GROUP_ORDER.size, group.title.to_s ] }
  end

  # A submission "changed" a value only when it edited a record that already
  # existed — a value replaced, or a blank filled, on that record (both come from
  # an update event). Creating new records and adding tags are a new submission's
  # own data, not edits, so they don't count. (This is why linking an org that
  # wasn't a clean match can raise the count: the fill lands on the existing org.)
  EDIT_OUTCOMES = %w[Replaced Filled].freeze

  def edited_groups
    groups.filter_map do |group|
      edits = group.changes.select { |change| EDIT_OUTCOMES.include?(change.outcome) }
      Group.new(record_type: group.record_type, title: group.title, changes: edits) if edits.any?
    end
  end

  def edited_count
    relevant_events.sum { |event| attribute_changes(event.properties["changes"] || {}).size }
  end

  def edited?
    edited_count.positive?
  end

  private

  def relevant_events
    Ahoy::Event
      .where("properties->>'$.form_submission_id' = ?", @form_submission.id.to_s)
      .order(:time, :id)
      .select { |event| event.properties["resource_type"].in?(RELEVANT_TYPES) }
  end

  # A tag row belongs to the person/organization it tags, not to itself, so its
  # changes group under that owner. Everything else owns its own changes.
  def owner_key(event)
    props = event.properties
    case props["resource_type"]
    when "SectorableItem" then [ props.dig("attributes", "sectorable_type"), props.dig("attributes", "sectorable_id") ]
    when "CategorizableItem" then [ props.dig("attributes", "categorizable_type"), props.dig("attributes", "categorizable_id") ]
    when "Address", "ContactMethod" then [ props.dig("attributes", "addressable_type") || props.dig("attributes", "contactable_type"), props.dig("attributes", "addressable_id") || props.dig("attributes", "contactable_id") ]
    else [ props["resource_type"], props["resource_id"] ]
    end
  end

  def build_group(type, id, events)
    changes = events.flat_map { |event| changes_for(event) }.compact
    Group.new(record_type: type, title: owner_title(type, id), changes: changes)
  end

  def changes_for(event)
    action = event.name.split(".").first
    props = event.properties

    return attribute_changes(props["changes"]) if props["changes"].present?
    return [ tag_change(action, event) ] if props["resource_type"].in?(%w[SectorableItem CategorizableItem])
    return [ record_change(action, event) ] if action.in?(%w[create destroy])

    []
  end

  def attribute_changes(changes)
    changes.except(*IGNORED_ATTRIBUTES).filter_map do |attribute, before_after|
      before, after = before_after.values_at("before", "after")
      next if after.blank? && before.blank?

      Change.new(
        outcome: before.present? ? "Replaced" : "Filled",
        label: attribute.humanize,
        value: display_value(after),
        previous_value: display_value(before)
      )
    end
  end

  def tag_change(action, event)
    props = event.properties
    if props["resource_type"] == "SectorableItem"
      name = Sector.find_by(id: props.dig("attributes", "sector_id"))&.name
      kind = "sector"
    else
      name = Category.find_by(id: props.dig("attributes", "category_id"))&.name
      kind = "age group"
    end
    primary = props.dig("attributes", "is_primary") ? " (primary)" : ""
    Change.new(outcome: action == "destroy" ? "Removed" : "Added", label: kind.humanize, value: "#{name}#{primary}")
  end

  def record_change(action, event)
    Change.new(
      outcome: action == "destroy" ? "Removed" : "Added",
      label: event.properties["resource_type"].underscore.humanize,
      value: event.properties["resource_title"]
    )
  end

  def owner_title(type, id)
    return type.to_s if id.blank?

    record = type.safe_constantize&.find_by(id: id)
    record&.try(:full_name).presence || record&.try(:name).presence || "#{type} ##{id}"
  end

  def display_value(value)
    value.is_a?(Array) ? value.join(", ") : value
  end
end
