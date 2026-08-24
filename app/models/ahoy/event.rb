class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, optional: true

  # Reading a record isn't a change to it. A record's change log asks what
  # happened to it, so these stay on the admin activities index, which is where
  # browsing belongs.
  NON_MUTATION_PREFIXES = %w[view print search filter download].freeze

  scope :mutations, -> {
    NON_MUTATION_PREFIXES.reduce(all) { |scope, prefix| scope.where.not(arel_table[:name].matches("#{prefix}.%")) }
  }
end
