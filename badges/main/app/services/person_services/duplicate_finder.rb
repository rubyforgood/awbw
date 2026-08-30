require "set"

module PersonServices
  # Surfaces likely-duplicate people for the deduper's candidate list. Clusters
  # people by several signals — nickname/legal-name-aware name match, shared
  # email (email or email_2), FileMaker code, and date of birth plus last name —
  # then annotates each cluster with why it was flagged. Two records grouped by
  # name but carrying different FileMaker codes are surfaced as a caution for an
  # admin to verify, never silently treated as a clean merge.
  class DuplicateFinder
    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def initialize(scope = Person.all)
      @people = scope.to_a
    end

    def groups
      union = UnionFind.new(@people.map(&:id))
      cluster(union) { |person| name_keys(person) }
      cluster(union) { |person| email_keys(person) }
      cluster(union) { |person| Array(filemaker_key(person)) }
      cluster(union) { |person| Array(dob_key(person)) }

      by_id = @people.index_by(&:id)
      union.components.filter_map do |ids|
        next if ids.size < 2
        records = ids.map { |id| by_id[id] }.sort_by(&:id)
        Group.new(
          key: records.map(&:id).join("-"),
          label: records.first.full_name.to_s,
          records: records,
          reasons: reasons_for(records)
        )
      end.sort_by { |group| group.label.to_s.downcase }
    end

    private

    def cluster(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @people.each do |person|
        yield(person).each { |key| buckets[key] << person.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def reasons_for(records)
      reasons = []
      exact = records.map { |person| exact_name_key(person) }.uniq
      if exact.size == 1
        reasons << "Same name"
      elsif shared?(records) { |person| name_keys(person) }
        reasons << "Same name (nickname or legal-name variant)"
      end

      reasons << "Shared email" if shared?(records) { |person| email_keys(person) }
      reasons << "Same date of birth" if shared?(records) { |person| Array(dob_key(person)) }
      reasons.concat(filemaker_reasons(records))
      reasons
    end

    def filemaker_reasons(records)
      codes = records.filter_map { |person| person.filemaker_code.presence }.uniq.sort
      return [] if codes.empty?
      return [ "⚠ Different FileMaker codes (#{codes.join(", ")}) — verify these are the same person" ] if codes.size > 1

      [ "Same FileMaker code (#{codes.first})" ]
    end

    def shared?(records)
      keys = records.flat_map { |person| Array(yield(person)) }
      keys.tally.any? { |_key, count| count > 1 }
    end

    # First-name variant (nickname or legal first name) paired with the last name,
    # so "Bob Smith" and "Robert Smith" share a key and cluster together.
    def name_keys(person)
      last = normalized(person.last_name)
      return [] if last.blank?

      first_forms = [ person.first_name, person.legal_first_name ].filter_map { |name| name.presence }
      first_forms.flat_map { |name| NicknameMap.variants_for(name) }.uniq.map { |variant| "#{variant}|#{last}" }
    end

    def exact_name_key(person)
      "#{NicknameMap.normalize(person.first_name)}|#{normalized(person.last_name)}"
    end

    def email_keys(person)
      [ person.email, person.email_2 ].filter_map { |email| email.to_s.strip.downcase.presence }
    end

    def filemaker_key(person)
      code = person.filemaker_code.to_s.strip.downcase
      "fm|#{code}" if code.present?
    end

    def dob_key(person)
      last = normalized(person.last_name)
      "dob|#{person.date_of_birth}|#{last}" if person.date_of_birth && last.present?
    end

    def normalized(value)
      NicknameMap.normalize(value)
    end
  end
end
