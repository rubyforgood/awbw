module AffiliationServices
  # People carrying two or more identical affiliations (AffiliationDeduper.duplicate_sets)
  # — the set the standalone affiliation deduper merges. Identity includes the person,
  # so grouping by person finds every duplicate an organization has too.
  class DuplicateFinder
    Group = Struct.new(:person, :duplicate_sets, keyword_init: true) do
      def label
        person.full_name
      end

      def merged_count
        duplicate_sets.sum { |affiliations| affiliations.size - 1 }
      end
    end

    def initialize(scope = Affiliation.all)
      @scope = scope
    end

    def groups
      @scope.where(person_id: duplicated_person_ids)
        .includes(:person, :organization, event_registration: :event).order(:id).to_a
        .group_by(&:person)
        .filter_map { |person, affiliations| group_for(person, affiliations) }
        .sort_by { |group| group.label.to_s.downcase }
    end

    private

    # Narrows the load to people with an exact copy in SQL; the Ruby pass applies the
    # deduper's own identity (e.g. a title differing only in surrounding spaces).
    def duplicated_person_ids
      @scope.group(:person_id, :organization_id, :type, :start_date, :end_date, :inactive)
        .having("COUNT(*) > 1").distinct.pluck(:person_id)
    end

    def group_for(person, affiliations)
      return unless person

      duplicate_sets = AffiliationDeduper.duplicate_sets(affiliations)
      return if duplicate_sets.empty?

      Group.new(person: person, duplicate_sets: duplicate_sets)
    end
  end
end
