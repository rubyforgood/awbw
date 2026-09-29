module PersonServices
  # After a person merge, the generic merge moves both people's addresses onto the
  # keeper wholesale (addresses have no unique index, so nothing collapses them),
  # leaving identical duplicates and possibly two primary addresses. Fold addresses
  # that share the same details into one — repointing their contact methods and
  # billing references via ModelDeduper#merge — then settle a single primary: the
  # keeper's own pre-merge primary, or the deleted person's when the keeper had none.
  # Runs in the people deduper's after_merge.
  class ReconcileAddresses
    IDENTITY_COLUMNS = %w[
      street_address city state zip_code country county district address_type locality
    ].freeze

    def self.signature(address)
      return unless address

      IDENTITY_COLUMNS.map { |column| address.public_send(column).to_s.strip.downcase }
    end

    # The signature of the primary address to preserve, read before the merge while
    # the two people's addresses can still be told apart: the keeper's own primary,
    # else the deleted person's.
    def self.primary_signature(keep, delete)
      signature(keep.addresses.find_by(primary: true)) ||
        signature(delete.addresses.find_by(primary: true))
    end

    def initialize(person, primary_signature: nil)
      @person = person
      @primary_signature = primary_signature
    end

    def call
      survivors = {}
      @person.addresses.reload.each do |address|
        signature = self.class.signature(address)
        if (survivor = survivors[signature])
          fold(address, into: survivor)
        else
          survivors[signature] = address
        end
      end

      settle_primary(survivors.values)
    end

    private

    def fold(loser, into:)
      deduper.merge(into, loser)
    end

    def settle_primary(addresses)
      return if @primary_signature.nil?

      addresses.each do |address|
        primary = self.class.signature(address) == @primary_signature
        address.update!(primary: primary) if address.primary? != primary
      end
    end

    def deduper
      @deduper ||= ModelDeduper.new(model_class: Address, logger: Rails.logger, dry_run: false)
    end
  end
end
