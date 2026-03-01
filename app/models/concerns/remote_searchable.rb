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

      terms = query.split
      scope = all

      terms.each_with_index do |term, i|
        pattern_key = :"pattern_#{i}"
        conditions = remote_search_columns
          .map { |column| "#{table_name}.#{column} LIKE :#{pattern_key}" }
          .join(" OR ")
        scope = scope.where(conditions, pattern_key => "%#{term}%")
      end

      scope
    end
  end

  def remote_search_label
    {
      id: id,
      label: public_send(self.class.remote_search_columns.first)
    }
  end
end
