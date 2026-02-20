module RemoteSearchable
  extend ActiveSupport::Concern

  class_methods do
    def remote_searchable_by(*columns)
      @remote_search_columns = columns.map(&:to_s)
    end

    def remote_search_columns
      @remote_search_columns || []
    end

    def remote_search(query)
      return none if query.blank?
      raise "remote_searchable_by not defined for #{name}" if remote_search_columns.empty?

      pattern = "%#{query}%"

      conditions = remote_search_columns
        .map { |column| "#{column} LIKE :pattern" }
        .join(" OR ")

      where(conditions, pattern: pattern)
    end
  end

  def remote_search_label
    {
      id: id,
      label: public_send(self.class.remote_search_columns.first)
    }
  end
end
