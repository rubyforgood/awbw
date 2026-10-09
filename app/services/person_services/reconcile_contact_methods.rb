module PersonServices
  # After a person merge, the generic merge moves both people's contact methods onto
  # the keeper wholesale (contact_methods have no unique index), leaving identical
  # duplicates and possibly two primary phones of the same kind. Fold contact methods
  # that share the same kind + value into one, then settle a single primary per kind:
  # the keeper's own pre-merge primary, or the deleted person's when the keeper had
  # none. Runs in the people deduper's after_merge.
  class ReconcileContactMethods
    IDENTITY_COLUMNS = %w[kind value contact_type].freeze

    # Outside the identity, so a fold never drops the address link only one copy had.
    CARRIED_COLUMNS = %w[address_id].freeze

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
      fold_candidates.each do |contact_method|
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

    # Active before inactive, then the primary, then oldest — so a fold keeps the
    # copy still in use. `Person#phone_number` reads only active phones, so letting
    # an inactive duplicate win would leave the person looking phoneless.
    def fold_candidates
      @person.contact_methods.reload.sort_by do |contact_method|
        [ contact_method.inactive? ? 1 : 0, contact_method.primary? ? 0 : 1, contact_method.id ]
      end
    end

    def fold(loser, into:)
      carry_over(loser, into)
      deduper.merge(into, loser)
    end

    def carry_over(loser, survivor)
      filled = CARRIED_COLUMNS.select do |column|
        survivor.public_send(column).blank? && loser.public_send(column).present?
      end
      return if filled.empty?

      survivor.update!(filled.index_with { |column| loser.public_send(column) })
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
