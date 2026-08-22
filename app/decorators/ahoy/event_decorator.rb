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

    def properties_count
      properties_hash.size
    end

    private

    def properties_hash
      object.properties || {}
    end

    def change_diffs
      properties_hash["changes"]
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
