module FmArchive
  extend ActiveSupport::Concern

  FIELD_GROUPS = {}.freeze
  OTHER_FIELDS = "Other fields"
  LISTED_FIELDS = [].freeze
  TALL_GROUPS = [].freeze
  PORTAL_COUNTERPARTS = {}.freeze
  PORTAL_FIELDS = {}.freeze
  USER_LOOKUP_FIELDS = [].freeze
  CONTEXT_LINK_MAP = {}.freeze
  PREFIX_LINK_MAP = {}.freeze

  included do
    before_validation :set_defaults
  end

  class_methods do
    def find_by_fm_id(id)
      find_by(fm_id: id)
    end

    def find_by_data(column, value)
      where("JSON_UNQUOTE(JSON_EXTRACT(data, CONCAT('$.', ?))) = ?", column.to_s, value)
    end

    # FIELD_GROUPS with each card's subcards lifted to the top level.
    def flat_field_groups
      self::FIELD_GROUPS.flat_map { |label, keys| keys.is_a?(Hash) ? keys.to_a : [ [ label, keys ] ] }.to_h
    end
  end

  # The filled-in data fields as cards of subcards, { card => { subcard => fields } }, in FIELD_GROUPS order.
  # A card listing its fields directly holds one unlabeled subcard; fields no group names trail under
  # "Other fields". Ungrouped tables come back whole, as one unlabeled card.
  def grouped_data
    groups = self.class::FIELD_GROUPS
    return { nil => { nil => data } } if groups.empty?

    filled = data.compact_blank.except(*self.class::LISTED_FIELDS)
    groups.merge(OTHER_FIELDS => ungrouped_keys).to_h do |label, keys|
      subgroups = keys.is_a?(Hash) ? keys : { nil => keys }
      [ label, subgroups.transform_values { |sub_keys| filled.slice(*sub_keys) }
                        .select { |sub_label, fields| fields.any? || records_listed_under(sub_label).any? } ]
    end.compact_blank
  end

  def ungrouped_keys
    data.keys - self.class.flat_field_groups.values.flatten
  end

  # A subcard of exactly one field, which reads as a single labeled row.
  def single_field_group?(label)
    self.class.flat_field_groups[label]&.one? && records_listed_under(label).none?
  end

  # What the portal calls its own records of the kind a related archive table holds.
  def portal_counterpart(table)
    self.class::PORTAL_COUNTERPARTS[table]
  end

  # Related records a subcard lists below its fields.
  def records_listed_under(_label)
    []
  end

  # The archive table a field's ID points at. A polymorphic field, mapped to nil in FM_LINKS, resolves
  # by the record's Context or by the ID's prefix.
  def reference_table(key)
    value = data[key]
    return if value.blank? || !self.class::FM_LINKS.key?(key)

    self.class::FM_LINKS[key] || self.class::CONTEXT_LINK_MAP[data["Context"]] || self.class::PREFIX_LINK_MAP[value.to_s[0]]
  end

  # Each table words its names its own way, so records from different tables never share one.
  def name
    fm_id
  end

  private

  def fm_value(*fields)
    fields.lazy.filter_map { |field| data&.dig(field).to_s.squish.presence }.first
  end

  def fm_join(*fields)
    fm_words(*fields.map { |field| fm_value(field) })
  end

  def fm_words(*parts)
    parts.compact_blank.join(" ").presence
  end

  def fm_with(preposition, value)
    "#{preposition} #{value}" if value.present?
  end

  def fm_dollars(*fields)
    amounts = fields.filter_map { |field| Float(fm_value(field)&.delete("$,"), exception: false) }
    MoneyFormatter.dollars_from_cents((amounts.sum * 100).round) if amounts.any?
  end

  # "Subject — detail", where the detail carries the table's own wording.
  def fm_phrase(subject, detail)
    return detail&.upcase_first || fm_id if subject.blank?
    [ subject, detail ].compact_blank.join(" — ")
  end

  def set_defaults
    self.data ||= {}
  end
end
