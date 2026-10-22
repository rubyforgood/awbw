# Drops pairs an admin marked "Not duplicates" from a duplicate finder's groups.
# A group splits wherever its remaining links break, and anything left alone drops off.
class NotDuplicateFilter
  def initialize(model_class)
    @model_class = model_class
  end

  def call(groups)
    pairs = NotDuplicatePair.id_pairs_for(@model_class)
    return groups if pairs.empty?

    groups.flat_map { |group| split(group, pairs) }
  end

  private

  def split(group, pairs)
    ids = group.records.map(&:id)
    union = UnionFind.new(ids)
    ids.combination(2) { |pair| union.union_all(pair) unless pairs.include?(pair.minmax) }

    union.components.filter_map do |component|
      next if component.size < 2

      group.dup.tap { |part| part.records = group.records.select { |record| component.include?(record.id) } }
    end
  end
end
