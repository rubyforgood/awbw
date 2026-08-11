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
    ATTRIBUTES = %w[field label value scope].freeze

    attr_reader :field, :label, :value, :scope

    def initialize(field:, label:, value:, scope: nil)
      @field = field.to_s
      @label = label
      @value = value.to_s
      @scope = scope.presence
    end

    # Rehydrate from the JSON column. Tolerates a row written before a key
    # existed rather than raising — this is a display aid, not a ledger we'd want
    # blowing up a page load.
    def self.from_json(raw)
      return if raw.blank?

      hash = raw.stringify_keys
      return if hash["field"].blank?

      new(field: hash["field"], label: hash["label"].presence || hash["field"], value: hash["value"], scope: hash["scope"])
    end

    def self.all_from_json(raw)
      Array(raw).filter_map { |entry| from_json(entry) }
    end

    def to_json_hash
      { "field" => field, "label" => label, "value" => value, "scope" => scope }.compact
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
