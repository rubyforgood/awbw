module NameFilterable
  extend ActiveSupport::Concern

  class_methods do
    def names(input)
      # Param not provided → do not filter
      return all if input.nil?

      parsed =
        Array(input)
          .flat_map { |v| v.to_s.split("--") }
          .map(&:strip)
          .reject(&:blank?)
          .map(&:downcase)

      # Param provided but empty → intentionally no matches
      return none if parsed.empty?

      conditions = parsed.map { "LOWER(name) LIKE ?" }.join(" OR ")
      values     = parsed.map { |v| "%#{v}%" }

      where(conditions, *values)
    end
  end
end
