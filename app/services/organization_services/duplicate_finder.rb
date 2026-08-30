require "set"

module OrganizationServices
  # Surfaces likely-duplicate organizations for the deduper's candidate list.
  # Clusters organizations by several signals — normalized name, name minus a
  # legal suffix (Inc/LLC/…), name minus a trailing audience word (Children's/
  # Adult/Combined/…), FileMaker code, and shared address — then annotates
  # each cluster with why it was flagged. FileMaker is the source of truth, so a
  # cluster whose members carry different FileMaker codes is surfaced as a
  # conflict for an admin to resolve, never silently treated as a clean merge.
  class DuplicateFinder
    LEGAL_SUFFIX = /\b(?:incorporated|inc|llc|l\.l\.c|corporation|corp|company|co|limited|ltd)\b\.?/i

    # Trailing audience descriptors that distinguish programs for the same org
    # (e.g. "… Children's" vs "… Adult"); ignored at the end of a name for
    # matching. Apostrophes are already stripped by #normalized_name, so
    # "children's" arrives as "childrens" and "adult's" as "adults".
    AUDIENCE_WORDS = %w[combined childrens children adult adults].freeze

    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def initialize(scope = Organization.all)
      @organizations = scope.includes(:addresses).to_a
    end

    def groups
      union = UnionFind.new(@organizations.map(&:id))
      cluster(union) { |org| [ normalized_name(org).presence ].compact }
      cluster(union) { |org| [ suffixless_name(org).presence ].compact }
      cluster(union) { |org| [ audience_stripped_name(org).presence ].compact }
      cluster(union) { |org| org.filemaker_codes }
      cluster(union) { |org| address_keys(org) }

      by_id = @organizations.index_by(&:id)
      union.components.filter_map do |ids|
        next if ids.size < 2
        records = ids.map { |id| by_id[id] }.sort_by(&:id)
        Group.new(
          key: records.map(&:id).join("-"),
          label: records.first.name.to_s,
          records: records,
          reasons: reasons_for(records)
        )
      end.sort_by { |group| group.label.to_s.downcase }
    end

    private

    def cluster(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @organizations.each do |org|
        yield(org).each { |key| buckets[key] << org.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def reasons_for(records)
      reasons = []
      normalized = records.map { |org| normalized_name(org) }.uniq
      reasons << "Same name" if normalized.size == 1

      suffixless = records.map { |org| suffixless_name(org) }.reject(&:blank?).uniq
      reasons << "Same name aside from Inc/LLC/etc." if normalized.size > 1 && suffixless.size == 1

      audience = records.map { |org| audience_stripped_name(org) }.reject(&:blank?).uniq
      reasons << "Same name aside from audience (children's/adult/etc.)" if normalized.size > 1 && suffixless.size > 1 && audience.size == 1

      reasons.concat(filemaker_reasons(records))

      keys = records.flat_map { |org| address_keys(org) }
      reasons << "Shared address" if keys.tally.any? { |_key, count| count > 1 }
      reasons
    end

    def filemaker_reasons(records)
      code_sets = records.map(&:filemaker_codes)
      present = code_sets.flatten.uniq.sort
      return [] if present.empty?
      return [ "⚠ Multiple FileMaker codes (#{present.join(", ")}) — merging keeps all of them" ] if present.size > 1
      return [ "FileMaker code on only one record" ] if code_sets.any?(&:empty?)

      [ "Same FileMaker code (#{present.first})" ]
    end

    def normalized_name(org)
      org.name.to_s.downcase.gsub(/['’]/, "").gsub(/[^a-z0-9 ]/, " ").squish
    end

    def suffixless_name(org)
      normalized_name(org).gsub(LEGAL_SUFFIX, "").squish
    end

    def audience_stripped_name(org)
      tokens = normalized_name(org).split
      tokens.pop while tokens.size > 1 && AUDIENCE_WORDS.include?(tokens.last)
      tokens.join(" ")
    end

    def address_keys(org)
      org.addresses.reject(&:inactive?).filter_map do |address|
        parts = [ address.street_address, address.city, address.zip_code ].map { |part| part.to_s.strip.downcase }
        next if parts.all?(&:blank?)
        parts.join("|")
      end
    end
  end
end
