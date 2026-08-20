module FmArchive
  extend ActiveSupport::Concern

  included do
    before_validation :set_defaults
  end

  class_methods do
    def find_by_fm_id(id)
      find_by(fm_id: id)
    end

    def find_by_data(column, value)
      column = column.to_s
      raise ArgumentError, "Invalid data column: #{column}" unless column.match?(/\A[A-Za-z0-9_]+\z/)

      where(Arel.sql("JSON_UNQUOTE(JSON_EXTRACT(data, '$.#{column}')) = :value"), value: value)
    end
  end

  private

  def set_defaults
    self.data ||= {}
  end
end
