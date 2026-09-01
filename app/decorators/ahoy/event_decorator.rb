module Ahoy
  class EventDecorator < ApplicationDecorator
    # Already surfaced in their own table columns, so redundant inside the details cell.
    REDUNDANT_KEYS = %w[resource_type resource_id resource_title].freeze

    # Fields that title the record they belong to, in the order they should lead.
    HEADING_KEYS = %w[topic title name subject].freeze

    # Plain-language chips for the raw "action.resource" event name, so a
    # non-technical reader sees "New" / "Edit" instead of "create." / "update.".
    # Colored ones flag record changes; everything else reads gray. Class literals
    # live here (decorators are Tailwind-scanned) so the chip generates.
    ACTION_CHIPS = {
      "create"      => { label: "New",      classes: "bg-blue-100 text-blue-800" },
      "update"      => { label: "Edit",     classes: "bg-green-100 text-green-800" },
      "destroy"     => { label: "Delete",   classes: "bg-red-100 text-red-800" },
      "autochange"  => { label: "Auto",     classes: "bg-gray-100 text-gray-600" },
      "view"        => { label: "View",     classes: "bg-gray-100 text-gray-600" },
      "print"       => { label: "Print",    classes: "bg-gray-100 text-gray-600" },
      "download"    => { label: "Download", classes: "bg-gray-100 text-gray-600" },
      "search"      => { label: "Search",   classes: "bg-gray-100 text-gray-600" },
      "search_zero" => { label: "Search",   classes: "bg-gray-100 text-gray-600" },
      "filter"      => { label: "Filter",   classes: "bg-gray-100 text-gray-600" },
      "auth"        => { label: "Account",  classes: "bg-gray-100 text-gray-600" },
      "dedupe"      => { label: "Merge",    classes: "bg-gray-100 text-gray-600" }
    }.freeze
    DEFAULT_CHIP_CLASSES = "bg-gray-100 text-gray-600".freeze

    # { label:, classes: } for the leading action chip.
    def activity_chip
      ACTION_CHIPS[action_key] || { label: action_key.humanize, classes: DEFAULT_CHIP_CLASSES }
    end

    # The resource half of the event name, humanized: "workshop_variation" reads
    # "Workshop variation", "account_deactivated" reads "Account deactivated".
    def activity_resource_label
      object.name.to_s.split(".", 2)[1].to_s.humanize
    end

    # The event's own resource, linked to its edit page so an admin can jump
    # straight there from the timeline. Title comes from properties; the record
    # resolves through the page cache (Analytics::EventReferenceLoader). Returns
    # nil when there's no title; :path is nil when the record is gone or has no
    # editable route (rendered as plain text).
    def resource_link
      title = properties_hash["resource_title"]
      return nil if title.blank?

      record = find_referenced_record(object.resource_type, object.resource_id)
      { text: title, path: edit_path_for(record) }
    end

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

      change_diffs.filter_map do |field, diff|
        diff = {} unless diff.is_a?(Hash)
        next if blank_change?(diff)

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

    def action_key
      object.name.to_s.split(".", 2).first.to_s
    end

    # Prefer the record's edit page (the point of the link), falling back to its
    # show page, then to nothing when neither route exists.
    def edit_path_for(record)
      return nil unless record

      h.edit_polymorphic_path(record)
    rescue StandardError
      show_path_for(record)
    end

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
      heading_first(hash).each do |key, val|
        child_rows = flatten_rows(val, humanize_key(key), child_depth)
        child_rows.first[:emphasis] = true if HEADING_KEYS.include?(key.to_s) && child_rows.one?
        rows.concat(child_rows)
      end
      rows
    end

    # A comment's topic titles its body rather than sitting beside it, so it leads.
    def heading_first(hash)
      headings, rest = hash.partition { |key, _| HEADING_KEYS.include?(key.to_s) }
      headings.sort_by { |key, _| HEADING_KEYS.index(key.to_s) } + rest
    end

    def array_rows(array, label, depth)
      return [ { label: label, value: "(empty)", depth: depth } ] if array.empty?

      if array.all? { |item| named_entity?(item) }
        [ { label: label, value: array.map { |item| entity_label(item) }.join(", "), depth: depth } ]
      elsif array.all? { |item| reference?(item) }
        header = label ? [ { label: label, value: nil, depth: depth } ] : []
        child_depth = label ? depth + 1 : depth
        header + array.flat_map { |item| reference_rows(nil, item, child_depth) }
      elsif array.all? { |item| attachment_change?(item) }
        array.map { |item| attachment_row(label, item, depth) }
      else
        [ { label: label, value: array.map { |item| display_value(item) }.join(", "), depth: depth } ]
      end
    end

    def reference?(item)
      Analytics::EventReferenceLoader.reference?(item)
    end

    # An attachment is staged on the record and has no id until the save lands,
    # so it travels as a filename rather than as a reference to look up.
    def attachment_change?(item)
      item.is_a?(Hash) && item["type"] == "ActiveStorage::Attachment" &&
        item["action"].present? && item["id"].blank? && item["record_id"].blank?
    end

    # A file has no page to link to, so it reads as its name — kept on a removal
    # too, since the blob it named is gone by the time anyone reads this.
    def attachment_row(label, item, depth)
      { label: label, depth: depth, action: item["action"], value: item["filename"].presence }
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
      rows = [ reference_row(label, item, depth) ]
      rows += change_rows(item["changes"], depth + 1)
      rows += flatten_rows(item["attributes"], nil, depth + 1) if item["attributes"].present?
      rows
    end

    # A nested record's diffs read like the record's own: field, then before, then
    # after. The order comes from here rather than the payload — MySQL reorders
    # the keys of a JSON object.
    def change_rows(diffs, depth)
      return [] unless diffs.is_a?(Hash)

      diffs.filter_map do |field, diff|
        diff = {} unless diff.is_a?(Hash)
        next if blank_change?(diff)

        { label: humanize_key(field), depth: depth,
          change: { before: display_value(diff["before"]), after: display_value(diff["after"]) } }
      end
    end

    def blank_change?(diff)
      diff["before"].blank? && diff["after"].blank?
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
