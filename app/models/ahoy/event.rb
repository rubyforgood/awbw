class Ahoy::Event < ApplicationRecord
  include Ahoy::QueryMethods

  self.table_name = "ahoy_events"

  belongs_to :visit
  belongs_to :user, optional: true

  # Reading a record isn't a change to it. A record's change log asks what
  # happened to it, so these stay on the admin activities index, which is where
  # browsing belongs.
  NON_MUTATION_PREFIXES = %w[view print search filter download].freeze

  # Event-name patterns the activities index can toggle off in bulk.
  #
  # Account = the user/account lifecycle: every auth.* callback (login, password
  # reset, email change, lock, admin grant, account setup/delete, …) plus
  # mutations of the User record itself, so one "account" toggle sweeps all user
  # churn out of a person's timeline.
  #
  # Interaction = read/browse noise (NON_MUTATION_PREFIXES plus zero-result
  # searches).
  ACCOUNT_NAME_PATTERNS = [ "auth.%", "create.user", "update.user", "destroy.user" ].freeze
  INTERACTION_NAME_PATTERNS = (NON_MUTATION_PREFIXES + %w[search_zero]).map { |prefix| "#{prefix}.%" }.freeze

  scope :mutations, -> {
    NON_MUTATION_PREFIXES.reduce(all) { |scope, prefix| scope.where.not(arel_table[:name].matches("#{prefix}.%")) }
  }
end
