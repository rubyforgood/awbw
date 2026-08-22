module Ahoy
  class EventDecorator < ApplicationDecorator
    # Already surfaced in their own table columns, so redundant inside the details cell.
    REDUNDANT_KEYS = %w[resource_type resource_id resource_title].freeze

    # Everything the dedicated columns don't already show.
    def extra_properties
      properties_hash.except(*REDUNDANT_KEYS)
    end

    def extra_details?
      extra_properties.present?
    end

    def changes?
      change_diffs.is_a?(Hash) && change_diffs.present?
    end

    # Field-level before/after diffs for update events, humanized for a
    # non-technical reader: [{ field:, before:, after: }, ...].
    def changes_summary
      return [] unless changes?

      change_diffs.map do |field, diff|
        diff = {} unless diff.is_a?(Hash)
        {
          field: field.to_s.humanize,
          before: display_value(diff["before"]),
          after: display_value(diff["after"])
        }
      end
    end

    # Every non-change extra property flattened into readable, humanized rows
    # for inline display: [{ label:, value:, depth: }, ...]. Nested hashes and
    # arrays are indented under their parent (depth) so the whole payload is
    # visible in the table without opening the detail page.
    def detail_rows
      rows = extra_properties.except("changes")
      return [] if rows.empty?

      flatten_rows(rows)
    end

    private

    def properties_hash
      object.properties || {}
    end

    def change_diffs
      properties_hash["changes"]
    end

    def flatten_rows(value, label = nil, depth = 0)
      case value
      when Hash
        nested_rows(value, label, depth)
      when Array
        array_rows(value, label, depth)
      else
        [ { label: label, value: display_value(value), depth: depth } ]
      end
    end

    def nested_rows(hash, label, depth)
      return [ { label: label, value: "(empty)", depth: depth } ] if hash.empty?

      rows = label ? [ { label: label, value: nil, depth: depth } ] : []
      child_depth = label ? depth + 1 : depth
      hash.each do |key, val|
        rows.concat(flatten_rows(val, key.to_s.humanize, child_depth))
      end
      rows
    end

    def array_rows(array, label, depth)
      return [ { label: label, value: "(empty)", depth: depth } ] if array.empty?

      if array.all? { |item| item.is_a?(Hash) }
        rows = label ? [ { label: label, value: nil, depth: depth } ] : []
        child_depth = label ? depth + 1 : depth
        array.each { |item| rows.concat(nested_rows(item, nil, child_depth)) }
        rows
      else
        [ { label: label, value: array.map { |item| display_value(item) }.join(", "), depth: depth } ]
      end
    end

    def display_value(value)
      case value
      when nil, "" then "(empty)"
      when true then "Yes"
      when false then "No"
      when Hash, Array then value.to_json
      else value.to_s
      end
    end
  end
end
