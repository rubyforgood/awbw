# app/models/concerns/tag_filterable.rb
module TagFilterable
  extend ActiveSupport::Concern

  class_methods do
    def tag_names(association, names)
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

      joins(association)
        .where("LOWER(#{table_name}.name) IN (?)", parsed_names)
        .distinct
    end
  end
end
