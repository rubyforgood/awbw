module FmArchive
  extend ActiveSupport::Concern

  FIELD_GROUPS = {}.freeze

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

  # The data fields clustered under FIELD_GROUPS headings, in their listed order; fields no group names
  # trail under "Other fields". Ungrouped tables come back as one unlabeled group.
  def grouped_data
    groups = self.class::FIELD_GROUPS
    return { nil => data } if groups.empty?

    groups.transform_values { |keys| data.slice(*keys) }
      .merge("Other fields" => data.except(*groups.values.flatten))
      .compact_blank
  end

  private

  def set_defaults
    self.data ||= {}
  end
end
