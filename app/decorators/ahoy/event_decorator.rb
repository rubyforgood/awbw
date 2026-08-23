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

    # Every non-change extra property flattened into compact, humanized rows for
    # inline display. Row shapes:
    #   { label:, value:, depth: }                  plain label/value (value nil = header)
    #   { label:, action:, link: { text:, path: }, depth: }  record reference (linked)
    # Lists of named entities (filter sectors/categories) collapse onto one line;
    # record references (association changes, associated records) become links to
    # the record's show page so admins can jump straight to it.
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
      when Hash then hash_rows(value, label, depth)
      when Array then array_rows(value, label, depth)
      else [ { label: label, value: display_value(value), depth: depth } ]
      end
    end

    def hash_rows(hash, label, depth)
      return reference_rows(label, hash, depth) if reference?(hash)
      return [ { label: label, value: "(empty)", depth: depth } ] if hash.empty?

      rows = label ? [ { label: label, value: nil, depth: depth } ] : []
      child_depth = label ? depth + 1 : depth
      hash.each { |key, val| rows.concat(flatten_rows(val, humanize_key(key), child_depth)) }
      rows
    end

    def array_rows(array, label, depth)
      return [ { label: label, value: "(empty)", depth: depth } ] if array.empty?

      if array.all? { |item| named_entity?(item) }
        [ { label: label, value: array.map { |item| entity_label(item) }.join(", "), depth: depth } ]
      elsif array.all? { |item| reference?(item) }
        header = label ? [ { label: label, value: nil, depth: depth } ] : []
        child_depth = label ? depth + 1 : depth
        header + array.flat_map { |item| reference_rows(nil, item, child_depth) }
      else
        [ { label: label, value: array.map { |item| display_value(item) }.join(", "), depth: depth } ]
      end
    end

    def reference?(item)
      Analytics::EventReferenceLoader.reference?(item)
    end

    def named_entity?(item)
      item.is_a?(Hash) && (item["name"].present? || item["title"].present?)
    end

    def entity_label(item)
      name = item["name"] || item["title"]
      type = item["type"]
      type.present? ? "#{name} (#{type.to_s.underscore.humanize})" : name
    end

    # The link, then what the record actually said — a comment's body reads better
    # than "a comment was added".
    def reference_rows(label, item, depth)
      detail = item["changes"].presence || item["attributes"].presence
      rows = [ reference_row(label, item, depth) ]
      return rows if detail.blank?

      rows + flatten_rows(detail, nil, depth + 1)
    end

    def reference_row(label, item, depth)
      type = item["type"] || item["record_type"]
      id = item["id"] || item["record_id"]
      record = find_referenced_record(type, id)
      text = safe_label(record) || "#{type} ##{id}"
      { label: label, depth: depth, action: item["action"],
        link: { text: text, path: show_path_for(record) } }
    end

    # A model's own title/name can raise on records it wasn't written for, and a
    # change log is not the place to find out.
    def safe_label(record)
      label = record.try(:title).presence || record.try(:name).presence
      label.is_a?(String) ? label : label&.to_s
    rescue StandardError
      nil
    end

    # Prefer the page-level cache (one query per type, built by
    # Analytics::EventReferenceLoader) and only fall back to a direct lookup when
    # no cache was supplied (e.g. specs or the single-event detail page).
    def find_referenced_record(type, id)
      cache = context[:record_cache]
      return cache[[ type.to_s, id ]] if cache

      klass = type.to_s.safe_constantize
      return nil unless klass.respond_to?(:find_by) && klass < ApplicationRecord

      klass.find_by(id: id)
    rescue StandardError
      nil
    end

    def show_path_for(record)
      return nil unless record

      h.polymorphic_path(record)
    rescue StandardError
      nil
    end

    # Friendlier labels for keys whose humanized form is dev-speak. Both
    # result_count (index searches) and the legacy page_result_count (older
    # tagging events, before both unified on result_count) read the same.
    KEY_LABELS = {
      "result_count" => "Results found",
      "page_result_count" => "Results found"
    }.freeze
    private_constant :KEY_LABELS

    def humanize_key(key)
      KEY_LABELS[key.to_s] || key.to_s.humanize
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
