module TagFilterable
  extend ActiveSupport::Concern

  included do
    # Use _all suffix to indicate AND logic (matches items with ALL specified tags)
    scope :category_names_all, ->(names) { names.nil? ? all : tag_names_all(:categories, names) }
    scope :sector_names_all, ->(names) { names.nil? ? all : tag_names_all(:sectors, names) }
  end

  class_methods do
    # AND logic - matches items that have ALL of the specified tags
    # Uses subquery approach to avoid GROUP BY issues with eager loading
    def tag_names_all(association, names)
      return all if names.blank?

      parsed_names =
        Array(names)
          .flat_map { |n| n.to_s.split("--") }
          .map(&:strip)
          .reject(&:blank?)
          .map(&:downcase)

      return all if parsed_names.empty?

      reflection = reflect_on_association(association)
      table_name = reflection.klass.table_name

      # Use a subquery to find IDs that have all the specified tags
      # This avoids GROUP BY issues with eager loading
      subquery = joins(association)
        .where("LOWER(#{table_name}.name) IN (?)", parsed_names)
        .group("#{self.table_name}.id")
        .having("COUNT(DISTINCT LOWER(#{table_name}.name)) = ?", parsed_names.size)
        .select("#{self.table_name}.id")

      where(id: subquery)
    end
  end
end
