module Analytics
  # Batch-loads the records that Ahoy event properties reference (association
  # changes, associated records), so the activity table can link each one to its
  # show page without a per-reference query. Given the page's events, it scans
  # every properties tree once and issues a single query per referenced type.
  class EventReferenceLoader
    # A referenced record inside event properties: a type + id and nothing but
    # reference bookkeeping — no name/title (those render as a plain label) and
    # no snapshot columns. `label` is the record's name at the time, shown once
    # the record is gone.
    REFERENCE_KEYS = %w[type id record_type record_id action blob_id changes attributes label].freeze

    def self.reference?(item)
      return false unless item.is_a?(Hash)

      type = item["type"] || item["record_type"]
      has_id = item.key?("id") || item.key?("record_id")
      type.present? && has_id && item["name"].blank? && item["title"].blank? &&
        (item.keys - REFERENCE_KEYS).empty?
    end

    def self.pair(item)
      [ (item["type"] || item["record_type"]).to_s, item["id"] || item["record_id"] ]
    end

    # Polymorphic belongs_to columns in an attribute snapshot (commentable_id +
    # commentable_type), keyed by association name: { "commentable" => [type, id] }.
    def self.polymorphic_references(hash)
      hash.each_with_object({}) do |(key, type), refs|
        name = key.to_s.delete_suffix("_type")
        next if name == key.to_s || type.blank?

        id = hash["#{name}_id"]
        refs[name] = [ type.to_s, id ] if id.present?
      end
    end

    # The parents an update swapped on a polymorphic belongs_to (a moved comment):
    # { "commentable" => [[before_type, before_id], [after_type, after_id]] }. The
    # diff only carries the type when it changed, so otherwise it's read off the record.
    def self.polymorphic_changes(resource_type, changes, record)
      klass = resource_type.to_s.safe_constantize
      return {} unless changes.is_a?(Hash) && klass.respond_to?(:reflect_on_association)

      changes.each_with_object({}) do |(field, diff), moves|
        name = field.to_s.delete_suffix("_id")
        next if name == field.to_s || !diff.is_a?(Hash) || !klass.reflect_on_association(name)&.polymorphic?

        type_diff = changes["#{name}_type"]
        type_diff = { "before" => record&.public_send("#{name}_type"), "after" => record&.public_send("#{name}_type") } unless type_diff.is_a?(Hash)
        moves[name] = [ [ type_diff["before"], diff["before"] ], [ type_diff["after"], diff["after"] ] ]
      end
    end

    # Plain belongs_to foreign keys an update changed, so the diff can name the
    # records instead of showing ids: { "organization_address" => ["Address", before_id, after_id] }.
    def self.belongs_to_changes(resource_type, changes)
      klass = resource_type.to_s.safe_constantize
      return {} unless changes.is_a?(Hash) && klass.respond_to?(:reflect_on_all_associations)

      klass.reflect_on_all_associations(:belongs_to).reject(&:polymorphic?).each_with_object({}) do |reflection, refs|
        diff = changes[reflection.foreign_key.to_s]
        next unless diff.is_a?(Hash)

        refs[reflection.name.to_s] = [ reflection.class_name, diff["before"], diff["after"] ]
      end
    end

    # The submission a form-driven write was stamped with (Analytics::LifecycleBuffer).
    def self.form_submission_pair(properties)
      id = properties["form_submission_id"].presence
      [ "FormSubmission", id.to_i ] if id
    end

    def initialize(events)
      @events = events
    end

    # { [type, id] => record } for every reference across the events. A missing
    # record is simply absent from the map (the caller renders it as text).
    def records
      @records ||= load_records
    end

    private

    # A second pass picks up moved parents, whose type can come from the event's
    # own (first-pass) record.
    def load_records
      map = fetch(@events.flat_map { |event| primary_pairs(event) + submission_pairs(event) + references_in(event.properties || {}) + belongs_to_pairs(event) })
      map.merge(fetch(@events.flat_map { |event| moved_parent_pairs(event, map) } - map.keys))
    rescue StandardError
      {}
    end

    def fetch(pairs)
      pairs.uniq.select { |type, id| type.present? && id.present? }.group_by(&:first).each_with_object({}) do |(type, type_pairs), map|
        klass = type.safe_constantize
        next unless klass.respond_to?(:where) && klass < ApplicationRecord

        ids = type_pairs.map(&:last).uniq
        klass.where(id: ids).each { |record| map[[ type, record.id ]] = record }
      end
    end

    def belongs_to_pairs(event)
      self.class.belongs_to_changes(event.resource_type, event.properties&.dig("changes")).values.flat_map do |type, before, after|
        [ [ type, before ], [ type, after ] ]
      end
    end

    def moved_parent_pairs(event, map)
      record = map[[ event.resource_type.to_s, event.resource_id ]]
      changes = event.properties&.dig("changes")
      self.class.polymorphic_changes(event.resource_type, changes, record).values.flatten(1)
    end

    # The records an event names outside its properties tree: its own resource
    # (the resource_type/resource_id columns) and the change request an approval
    # stamped it with, so the timeline links both without a per-row query.
    def primary_pairs(event)
      change_request_id = (event.properties || {})[LifecycleBuffer::PROFILE_CHANGE_REQUEST_KEY]
      pairs = change_request_id.present? ? [ [ "ProfileChangeRequest", change_request_id ] ] : []
      return pairs if event.resource_type.blank? || event.resource_id.blank?

      pairs + [ [ event.resource_type.to_s, event.resource_id ] ]
    end

    def submission_pairs(event)
      [ self.class.form_submission_pair(event.properties || {}) ].compact
    end

    def references_in(value)
      case value
      when Hash
        return [ self.class.pair(value) ] if self.class.reference?(value)

        self.class.polymorphic_references(value).values +
          value.each_value.flat_map { |nested| references_in(nested) }
      when Array
        value.flat_map { |nested| references_in(nested) }
      else
        []
      end
    end
  end
end
