# Minimal disjoint-set: clusters ids connected by any shared signal into
# components, so a record linked by one signal to one duplicate and by another
# signal to a second lands in a single group. Used by the dedupe candidate
# finders (organizations, people).
class UnionFind
  def initialize(ids)
    @parent = ids.to_h { |id| [ id, id ] }
  end

  def union_all(ids)
    ids.each { |id| union(ids.first, id) }
  end

  def components
    @parent.keys.group_by { |id| find(id) }.values
  end

  private

  def find(id)
    id = @parent[id] while @parent[id] != id
    id
  end

  def union(a, b)
    @parent[find(a)] = find(b)
  end
end
