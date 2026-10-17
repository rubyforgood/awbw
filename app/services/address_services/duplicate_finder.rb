module AddressServices
  # People and organizations carrying two or more addresses with the same
  # AddressDeduper signature — the set the standalone address deduper folds.
  # Only compares addresses within one owner: two orgs sharing a street are
  # separate records, not duplicates.
  class DuplicateFinder
    Group = Struct.new(:addressable, :duplicate_sets, keyword_init: true) do
      def label
        addressable.try(:full_name).presence || addressable.name
      end

      def folded_count
        duplicate_sets.sum { |addresses| addresses.size - 1 }
      end
    end

    def initialize(scope = Address.all)
      @scope = scope
    end

    def groups
      @scope.includes(:addressable).order(:id).to_a
        .group_by { |address| [ address.addressable_type, address.addressable_id ] }
        .filter_map { |_owner, addresses| group_for(addresses) }
        .sort_by { |group| group.label.to_s.downcase }
    end

    private

    def group_for(addresses)
      addressable = addresses.first.addressable
      return unless addressable

      duplicate_sets = addresses.group_by { |address| AddressDeduper.signature(address) }
                                .values
                                .select { |set| set.size > 1 }
      return if duplicate_sets.empty?

      Group.new(addressable: addressable, duplicate_sets: duplicate_sets)
    end
  end
end
