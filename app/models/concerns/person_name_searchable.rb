module PersonNameSearchable
  extend ActiveSupport::Concern

  # Space-insensitive, first/last (and legal first) in either order, or each name alone.
  PERSON_NAME_SQL = <<~SQL.squish
    LOWER(REPLACE(CONCAT(people.first_name, people.last_name), ' ', '')) LIKE :needle
    OR LOWER(REPLACE(CONCAT(people.last_name, people.first_name), ' ', '')) LIKE :needle
    OR LOWER(REPLACE(CONCAT(people.legal_first_name, people.last_name), ' ', '')) LIKE :needle
    OR LOWER(REPLACE(CONCAT(people.last_name, people.legal_first_name), ' ', '')) LIKE :needle
    OR LOWER(REPLACE(people.first_name, ' ', '')) LIKE :needle
    OR LOWER(REPLACE(people.legal_first_name, ' ', '')) LIKE :needle
    OR LOWER(REPLACE(people.last_name, ' ', '')) LIKE :needle
  SQL

  class_methods do
    def by_person_name(query)
      return all if query.blank?

      joins(person_name_join).where(PERSON_NAME_SQL, needle: "%#{sanitize_sql_like(query.to_s.strip.downcase)}%")
    end

    def person_name_join = :person
  end
end
