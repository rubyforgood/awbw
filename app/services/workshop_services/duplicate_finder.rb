require "set"

module WorkshopServices
  # Surfaces likely-duplicate workshops for the deduper's candidate list.
  # Clusters workshops by normalized title and by title minus punctuation, then
  # annotates each cluster with why it was flagged. Deliberately conservative:
  # workshops that are genuine variations of one another live as separate records
  # linked through workshop_variations, so only near-identical titles cluster —
  # not a shared theme word.
  class DuplicateFinder
    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def initialize(scope = Workshop.all)
      @workshops = scope.to_a
    end

    def groups
      union = UnionFind.new(@workshops.map(&:id))
      cluster(union) { |workshop| [ normalized_title(workshop).presence ].compact }
      cluster(union) { |workshop| [ alnum_title(workshop).presence ].compact }

      by_id = @workshops.index_by(&:id)
      union.components.filter_map do |ids|
        next if ids.size < 2
        records = ids.map { |id| by_id[id] }.sort_by(&:id)
        Group.new(
          key: records.map(&:id).join("-"),
          label: records.first.title.to_s,
          records: records,
          reasons: reasons_for(records)
        )
      end.sort_by { |group| group.label.to_s.downcase }
    end

    private

    def cluster(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @workshops.each do |workshop|
        yield(workshop).each { |key| buckets[key] << workshop.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def reasons_for(records)
      reasons = []
      normalized = records.map { |workshop| normalized_title(workshop) }.uniq
      reasons << "Same title" if normalized.size == 1
      reasons << "Same title aside from punctuation" if normalized.size > 1
      reasons
    end

    def normalized_title(workshop)
      workshop.title.to_s.downcase.squish
    end

    def alnum_title(workshop)
      workshop.title.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").squish
    end
  end
end
