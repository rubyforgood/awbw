module PersonServices
  # After a person merge, the generic merge moves both people's contact methods onto
  # the keeper wholesale (contact_methods have no unique index), leaving identical
  # duplicates and possibly two primary phones of the same kind. Fold contact methods
  # that share the same kind + value into one, then settle a single primary per kind:
  # the keeper's own pre-merge primary, or the deleted person's when the keeper had
  # none. Runs in the people deduper's after_merge.
  class ReconcileContactMethods
    IDENTITY_COLUMNS = %w[kind value contact_type].freeze

    def self.signature(contact_method)
      return unless contact_method

      IDENTITY_COLUMNS.map { |column| contact_method.public_send(column).to_s.strip.downcase }
    end

    # One preserved-primary signature per kind, read before the merge while the two
    # people's contact methods can still be told apart: the keeper's own primary of
    # that kind, else the deleted person's.
    def self.primary_signatures(keep, delete)
      methods = keep.contact_methods.to_a + delete.contact_methods.to_a
      methods.map(&:kind).uniq.filter_map do |kind|
        primary = methods.find { |method| method.kind == kind && method.primary? && method.contactable == keep } ||
          methods.find { |method| method.kind == kind && method.primary? }
        signature(primary)
      end
    end

    def initialize(person, primary_signatures: [])
      @person = person
      @primary_signatures = primary_signatures
    end

    def call
      survivors = {}
      @person.contact_methods.reload.each do |contact_method|
        signature = self.class.signature(contact_method)
        if (survivor = survivors[signature])
          fold(contact_method, into: survivor)
        else
          survivors[signature] = contact_method
        end
      end

      settle_primary(survivors.values)
    end

    private

    def fold(loser, into:)
      deduper.merge(into, loser)
    end

    def settle_primary(contact_methods)
      contact_methods.each do |contact_method|
        primary = @primary_signatures.include?(self.class.signature(contact_method))
        contact_method.update!(primary: primary) if contact_method.primary? != primary
      end
    end

    def deduper
      @deduper ||= ModelDeduper.new(model_class: ContactMethod, logger: Rails.logger, dry_run: false)
    end
  end
end
