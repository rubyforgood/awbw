module OrganizationServices
  # One thing a registrant's form answers wrote onto an organization: which field,
  # and the value that landed in it. Produced by SyncProfile and UpsertAddress,
  # stored as JSON on EventRegistrationOrganization#form_autofill_changes, and
  # read back by the linking page so an admin can see not just that the form
  # changed the org but what it put there.
  #
  # `scope` names the address a field belongs to ("Austin work address"), since an
  # org accumulates one work address per city and "ZIP" alone wouldn't say which.
  # It's nil for the org's own columns, which are unambiguous.
  class AutofillChange
    # Whether the form put something where there was nothing, or replaced a value
    # an admin may have curated. Derived from previous_value rather than passed in,
    # so the two can never disagree once stored.
    NEW = "new".freeze
    UPDATE = "update".freeze

    attr_reader :field, :label, :value, :previous_value, :scope

    def initialize(field:, label:, value:, previous_value: nil, scope: nil)
      @field = field.to_s
      @label = label
      @value = value.to_s
      @previous_value = previous_value.presence&.to_s
      @scope = scope.presence
    end

    def change_type
      previous_value.present? ? UPDATE : NEW
    end

    def update?
      change_type == UPDATE
    end

    # Rehydrate from the JSON column. Tolerates a row written before a key
    # existed rather than raising — this is a display aid, not a ledger we'd want
    # blowing up a page load.
    def self.from_json(raw)
      return if raw.blank?

      hash = raw.stringify_keys
      return if hash["field"].blank?

      new(
        field: hash["field"],
        label: hash["label"].presence || hash["field"],
        value: hash["value"],
        previous_value: hash["previous_value"],
        scope: hash["scope"]
      )
    end

    def self.all_from_json(raw)
      Array(raw).filter_map { |entry| from_json(entry) }
    end

    # change_type is written out even though it's derivable, so the stored JSON
    # reads on its own without knowing the rule. previous_value is omitted for a
    # "new" change — there was nothing there to record.
    def to_json_hash
      {
        "field" => field,
        "label" => label,
        "value" => value,
        "change_type" => change_type,
        "previous_value" => previous_value,
        "scope" => scope
      }.compact
    end

    # What identifies this change for replacement: a later submission writing the
    # same field of the same address supersedes the earlier value rather than
    # stacking a second entry the admin has to reconcile.
    def key
      [ field, scope ]
    end

    # "Website", or "ZIP on the Austin work address" — the change without its value,
    # for a flash that has to stay to one line.
    def description
      scope.present? ? "#{label} on the #{scope}" : label
    end

    def ==(other)
      other.is_a?(self.class) && other.to_json_hash == to_json_hash
    end
    alias eql? ==

    def hash
      to_json_hash.hash
    end
  end
end
