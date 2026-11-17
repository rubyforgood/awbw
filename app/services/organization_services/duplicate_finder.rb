require "set"

module OrganizationServices
  # Surfaces likely-duplicate organizations for the deduper's candidate list.
  # Clusters organizations by several signals — normalized name, name minus a
  # legal suffix (Inc/LLC/…), name minus trailing audience words (Women's/
  # Children's/Combined/…) and FileMaker codes (the "(ORG00001)" the import gives
  # a namesake), FileMaker code, and shared address — then annotates
  # each cluster with why it was flagged. FileMaker is the source of truth, so a
  # cluster whose members carry different FileMaker codes is surfaced as a
  # conflict for an admin to resolve, never silently treated as a clean merge.
  class DuplicateFinder
    LEGAL_SUFFIX = /\b(?:incorporated|inc|llc|l\.l\.c|corporation|corp|company|co|limited|ltd)\b\.?/i

    # Trailing audience descriptors that distinguish programs for the same org
    # (e.g. "… Children's" vs "… Adult"); ignored at the end of a name for
    # matching. Apostrophes are already stripped by #normalized_name, so
    # "children's" arrives as "childrens" and "adult's" as "adults". Women and
    # Men also end real names ("Safe Place for Women"), so only their
    # possessives count.
    AUDIENCE_WORDS = %w[combined childrens children adult adults womens mens].freeze
    # A FileMaker org or project code as a name word, once #normalized_name has
    # dropped its parentheses: "Hope Center (ORG00001)" ends in "org00001".
    FILEMAKER_CODE_WORD = /\A(?:org|p)\d{4,}\z/

    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def self.normalized_name(name)
      name.to_s.downcase.gsub(/['’]/, "").gsub(/[^a-z0-9 ]/, " ").squish
    end

    def self.suffixless_name(name)
      normalized_name(name).gsub(LEGAL_SUFFIX, "").squish
    end

    def initialize(scope = Organization.all)
      @organizations = scope.includes(:addresses).to_a
    end

    def groups
      union = UnionFind.new(@organizations.map(&:id))
      cluster(union) { |org| [ normalized_name(org).presence ].compact }
      cluster(union) { |org| [ suffixless_name(org).presence ].compact }
      cluster(union) { |org| [ core_name(org).presence ].compact }
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

      codeless = records.map { |org| codeless_name(org) }.reject(&:blank?).uniq
      reasons << "Same name aside from a FileMaker code in the name" if normalized.size > 1 && codeless.size == 1

      core = records.map { |org| core_name(org) }.reject(&:blank?).uniq
      reasons << "Same name aside from audience (women's/children's/adult/etc.)" if normalized.size > 1 && suffixless.size > 1 && codeless.size > 1 && core.size == 1

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
      self.class.normalized_name(org.name)
    end

    def suffixless_name(org)
      self.class.suffixless_name(org.name)
    end

    def codeless_name(org)
      tokens = normalized_name(org).split
      tokens.pop while tokens.size > 1 && tokens.last.match?(FILEMAKER_CODE_WORD)
      tokens.join(" ")
    end

    # The name with its legal suffix and any trailing audience words and
    # FileMaker codes dropped, in whatever order they're stacked
    # ("Hope Center Women's (ORG00001)" → "hope center").
    def core_name(org)
      tokens = suffixless_name(org).split
      tokens.pop while tokens.size > 1 && trailing_noise?(tokens.last)
      tokens.join(" ")
    end

    def trailing_noise?(token)
      AUDIENCE_WORDS.include?(token) || token.match?(FILEMAKER_CODE_WORD)
    end

    def address_keys(org)
      org.addresses.reject(&:inactive?).filter_map do |address|
        parts = [
          AddressNormalizer.street(address.street_address),
          AddressNormalizer.city(address.city),
          AddressNormalizer.zip(address.zip_code)
        ]
        next if parts.all?(&:blank?)
        parts.join("|")
      end
    end
  end
end
