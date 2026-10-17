module DataHealth
  # People with more than one primary sector or primary age range. Both rules are
  # validated now, so these are rows saved before the rule, or written around it.
  class PeopleWithSeveralPrimaries < Check
    def title = "People with more than one primary sector or age range"

    def explanation
      "A person has one primary sector and one primary age range, with the rest listed as " \
      "additional. These were saved before that rule, so which one is primary needs a person to choose."
    end

    def scope
      Person.where(id: several_primary_sectors).or(Person.where(id: several_primary_age_ranges))
    end

    def describe(person)
      "#{person.name} — #{primary_summary(person)}"
    end

    def path_for(person) = edit_person_path(person)

    private

    def several_primary_sectors
      SectorableItem.where(sectorable_type: Person.polymorphic_name, is_primary: true)
        .group(:sectorable_id).having("COUNT(*) > 1").select(:sectorable_id)
    end

    def several_primary_age_ranges
      primary_age_range_items
        .group(:categorizable_id).having("COUNT(*) > 1").select(:categorizable_id)
    end

    def primary_age_range_items
      CategorizableItem.joins(category: :category_type)
        .where(category_types: { name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE })
        .where(categorizable_type: Person.polymorphic_name, is_primary: true)
    end

    def primary_summary(person)
      sectors = SectorableItem.where(sectorable: person, is_primary: true).count
      age_ranges = primary_age_range_items.where(categorizable_id: person.id).count
      [
        ("#{sectors} primary sectors" if sectors > 1),
        ("#{age_ranges} primary age ranges" if age_ranges > 1)
      ].compact.join(", ")
    end
  end
end
