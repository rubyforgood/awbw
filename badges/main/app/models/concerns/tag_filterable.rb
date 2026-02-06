module TagFilterable
  extend ActiveSupport::Concern

  included do
    scope :category_names, ->(names) { names.nil? ? all : tag_names(:categories, names) }
    scope :sector_names,   ->(names) { names.nil? ? all : tag_names(:sectors, names) }
  end

  class_methods do
    def tag_names(association, names, match: :all)
      return none if names.blank? # param present but empty

      parsed_names =
        Array(names)
          .flat_map { |n| n.to_s.split("--") }
          .map(&:strip)
          .reject(&:blank?)
          .map(&:downcase)

      return none if parsed_names.empty?

      reflection   = reflect_on_association(association)
      table_name   = reflection.klass.table_name
      parent_table = self.table_name

      relation =
        joins(association)
          .where("LOWER(#{table_name}.name) IN (?)", parsed_names)

      match == :all ?
        relation.group("#{parent_table}.id")
                .having("COUNT(DISTINCT #{table_name}.id) = ?", parsed_names.size)
        :
        relation.distinct
    end
  end
end
