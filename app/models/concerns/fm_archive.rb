module FmArchive
  extend ActiveSupport::Concern

  FIELD_GROUPS = {}.freeze
  OTHER_FIELDS = "Other fields"
  LISTED_FIELDS = [].freeze
  TALL_GROUPS = [].freeze

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

  # Related records a subcard lists below its fields.
  def records_listed_under(_label)
    []
  end

  private

  def set_defaults
    self.data ||= {}
  end
end
