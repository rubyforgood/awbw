module NameFilterable
  extend ActiveSupport::Concern

  class_methods do
    def names(input)
      return none if input.blank?

      parsed =
        Array(input)
          .flat_map { |v| v.to_s.split("--") }
          .map(&:strip)
          .reject(&:blank?)
          .map(&:downcase)

      return none if parsed.empty?

      conditions = parsed.map { "LOWER(name) LIKE ?" }.join(" OR ")
      values     = parsed.map { |v| "%#{v}%" }

      where(conditions, *values)
    end
  end
end
