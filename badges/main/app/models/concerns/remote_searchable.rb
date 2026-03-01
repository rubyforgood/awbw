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

      words = query.split.flat_map { |w| w.split(/[\s\-]+/) }.reject(&:blank?)
      return none if words.blank?

      conditions = words.each_with_index.map do |word, i|
        bind_var = "pattern_#{i}".to_sym
        column_conditions = remote_search_columns.map { |column| "#{table_name}.#{column} LIKE :#{bind_var}" }
        "(#{column_conditions.join(' OR ')})"
      end
      bindings = words.each_with_index.each_with_object({}) do |(word, i), hash|
        hash["pattern_#{i}".to_sym] = "%#{word}%"
      end
      where(conditions.join(" AND "), bindings)
        .order(remote_search_columns.index_with { :asc })
    end
  end

  def remote_search_label
    {
      id: id,
      label: public_send(self.class.remote_search_columns.first)
    }
  end
end
