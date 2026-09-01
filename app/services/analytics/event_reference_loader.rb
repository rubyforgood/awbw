module Analytics
  # Batch-loads the records that Ahoy event properties reference (association
  # changes, associated records), so the activity table can link each one to its
  # show page without a per-reference query. Given the page's events, it scans
  # every properties tree once and issues a single query per referenced type.
  class EventReferenceLoader
    # A referenced record inside event properties: a type + id and nothing but
    # reference bookkeeping — no name/title (those render as a plain label) and
    # no snapshot columns.
    REFERENCE_KEYS = %w[type id record_type record_id action blob_id changes attributes].freeze

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

    def initialize(events)
      @events = events
    end

    # { [type, id] => record } for every reference across the events. A missing
    # record is simply absent from the map (the caller renders it as text).
    def records
      @records ||= load_records
    end

    private

    def load_records
      pairs = @events.flat_map { |event| primary_pairs(event) + references_in(event.properties || {}) }.uniq
      pairs.group_by(&:first).each_with_object({}) do |(type, type_pairs), map|
        klass = type.safe_constantize
        next unless klass.respond_to?(:where) && klass < ApplicationRecord

        ids = type_pairs.map(&:last).uniq
        klass.where(id: ids).each { |record| map[[ type, record.id ]] = record }
      end
    rescue StandardError
      {}
    end

    # The event's own resource (its resource_type/resource_id columns), so the
    # timeline can link the resource title to the record without a per-row query.
    def primary_pairs(event)
      return [] if event.resource_type.blank? || event.resource_id.blank?

      [ [ event.resource_type.to_s, event.resource_id ] ]
    end

    def references_in(value)
      case value
      when Hash
        return [ self.class.pair(value) ] if self.class.reference?(value)

        value.each_value.flat_map { |nested| references_in(nested) }
      when Array
        value.flat_map { |nested| references_in(nested) }
      else
        []
      end
    end
  end
end
