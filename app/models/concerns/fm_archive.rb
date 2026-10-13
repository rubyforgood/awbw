module FmArchive
  extend ActiveSupport::Concern

  FIELD_GROUPS = {}.freeze
  OTHER_FIELDS = "Other fields"

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
  end

  # The filled-in data fields clustered under FIELD_GROUPS headings, in their listed order; fields no group
  # names trail under "Other fields". Ungrouped tables come back whole, as one unlabeled group.
  def grouped_data
    groups = self.class::FIELD_GROUPS
    return { nil => data } if groups.empty?

    filled = data.compact_blank
    groups.transform_values { |keys| filled.slice(*keys) }
      .merge(OTHER_FIELDS => filled.slice(*ungrouped_keys))
      .select { |label, fields| fields.any? || keep_empty_group?(label) }
  end

  def ungrouped_keys
    data.keys - self.class::FIELD_GROUPS.values.flatten
  end

  private

  def keep_empty_group?(_label)
    false
  end

  def set_defaults
    self.data ||= {}
  end
end
