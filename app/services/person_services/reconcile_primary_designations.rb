module PersonServices
  # After a person merge, the kept person holds both people's sector and age-range
  # taggings. Identical taggings (same sector / same age range) collapse to one in
  # the merge, but the surviving row keeps whichever primary flag the kept person's
  # own tagging had — which can drop a primary, or leave two different sectors both
  # flagged primary. Either way Person's single-primary validations would then reject
  # the record and block its next edit.
  #
  # Settle it to exactly one primary per dimension: the survivor's own pre-merge
  # primary, or — when the survivor had none — the deleted person's. That target id
  # is captured before the merge (afterwards the merged-in taggings are
  # indistinguishable from the survivor's own). Promote the target tagging and demote
  # every other, so a collapsed-away flag is restored and duplicate primaries are cleared.
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

    def reconcile(association, key, target_id)
      return unless target_id

      association.where(is_primary: true).where.not(key => target_id).find_each { |item| item.update!(is_primary: false) }
      target = association.find_by(key => target_id)
      target.update!(is_primary: true) if target && !target.is_primary?
      association.reset
    end
  end
end
