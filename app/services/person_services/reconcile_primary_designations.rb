module PersonServices
  # After a person merge, the kept person holds both people's sector and age-range
  # taggings — so it can end up with two "primary" sectors or two primary age
  # ranges, which Person's single-primary validations reject (and which would then
  # block the next edit). Keep the survivor's own primary designation and demote the
  # ones that rode in from the deleted person. When the survivor had no primary of
  # its own, keep a single one of the merged-in primaries so the invariant still holds.
  #
  # The survivor's pre-merge primary ids are captured before the merge moves anything
  # (the merged-in taggings are otherwise indistinguishable from the survivor's own).
  class ReconcilePrimaryDesignations
    def initialize(person, primary_sector_id:, primary_age_category_id:)
      @person = person
      @primary_sector_id = primary_sector_id
      @primary_age_category_id = primary_age_category_id
    end

    def call
      reconcile(@person.sectorable_items, :sector_id, @primary_sector_id)
      reconcile(@person.age_range_categorizable_items, :category_id, @primary_age_category_id)
    end

    private

    def reconcile(association, key, preferred_id)
      primaries = association.where(is_primary: true).to_a
      return if primaries.size <= 1

      keeper = primaries.find { |item| item.public_send(key) == preferred_id } || primaries.first
      (primaries - [ keeper ]).each { |item| item.update!(is_primary: false) }
      association.reset
    end
  end
end
