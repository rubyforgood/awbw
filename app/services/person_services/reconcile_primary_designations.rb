module PersonServices
  # Settles a merged person to exactly one primary sector and one primary age range,
  # as Person's single-primary validations require. The target for each dimension is
  # the survivor's own pre-merge primary, or — when it had none — the deleted person's;
  # it's passed in because it must be read before the merge, while the merged-in
  # taggings can still be told apart from the survivor's own. The target tagging is
  # marked primary and every other demoted.
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
