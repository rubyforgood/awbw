require "set"

module EventRegistrationServices
  # Surfaces likely-duplicate registrations for the deduper's candidate list. The
  # (registrant_id, event_id) unique index already forbids one person registering
  # for the same event twice, so a duplicate is one real person registered for the
  # same event under two different Person records. Clusters registrations for the
  # same event whose registrants share a signal — nickname/legal-name-aware name,
  # email (or email_2), or FileMaker code — then annotates each cluster with why it
  # was flagged. Registrants grouped by name but carrying different FileMaker codes
  # are surfaced as a caution to verify, never silently treated as a clean merge.
  class DuplicateFinder
    Group = Struct.new(:key, :label, :records, :reasons, keyword_init: true)

    def initialize(scope = EventRegistration.all)
      @registrations = scope.includes(:registrant, :event).to_a
    end

    def groups
      union = UnionFind.new(@registrations.map(&:id))
      cluster(union) { |registration| name_keys(registration) }
      cluster(union) { |registration| email_keys(registration) }
      cluster(union) { |registration| Array(filemaker_key(registration)) }

      by_id = @registrations.index_by(&:id)
      union.components.filter_map do |ids|
        next if ids.size < 2
        records = ids.map { |id| by_id[id] }.sort_by(&:id)
        Group.new(
          key: records.map(&:id).join("-"),
          label: label_for(records),
          records: records,
          reasons: reasons_for(records)
        )
      end.sort_by { |group| group.label.to_s.downcase }
    end

    private

    def cluster(union)
      buckets = Hash.new { |hash, key| hash[key] = [] }
      @registrations.each do |registration|
        yield(registration).each { |key| buckets[key] << registration.id }
      end
      buckets.each_value { |ids| union.union_all(ids) if ids.size > 1 }
    end

    def label_for(records)
      registrant = records.first.registrant
      "#{registrant&.full_name} — #{records.first.event&.title}"
    end

    def reasons_for(records)
      reasons = []
      reasons << "Same registrant name" if shared?(records) { |registration| name_keys(registration) }
      reasons << "Shared registrant email" if shared?(records) { |registration| email_keys(registration) }
      reasons.concat(filemaker_reasons(records))
      reasons
    end

    def filemaker_reasons(records)
      codes = records.filter_map { |registration| registration.registrant&.filemaker_code.presence }.uniq.sort
      return [] if codes.empty?
      return [ "⚠ Different FileMaker codes (#{codes.join(", ")}) — verify these are the same person" ] if codes.size > 1

      [ "Same registrant FileMaker code (#{codes.first})" ]
    end

    def shared?(records)
      keys = records.flat_map { |registration| Array(yield(registration)) }
      keys.tally.any? { |_key, count| count > 1 }
    end

    # Only registrations for the same event can be duplicates, so every signal is
    # scoped by event_id — the same person on two different events is legitimate.
    # First-name variant (nickname or legal first name) paired with the last name,
    # so "Bob Smith" and "Robert Smith" on one event cluster together.
    def name_keys(registration)
      registrant = registration.registrant
      last = normalized(registrant&.last_name)
      return [] if last.blank?

      first_forms = [ registrant&.first_name, registrant&.legal_first_name ].filter_map { |name| name.presence }
      first_forms
        .flat_map { |name| NicknameMap.variants_for(name) }
        .uniq
        .map { |variant| "#{registration.event_id}|#{variant}|#{last}" }
    end

    def email_keys(registration)
      registrant = registration.registrant
      [ registrant&.email, registrant&.email_2 ]
        .filter_map { |email| email.to_s.strip.downcase.presence }
        .map { |email| "#{registration.event_id}|#{email}" }
    end

    def filemaker_key(registration)
      code = registration.registrant&.filemaker_code.to_s.strip.downcase
      "#{registration.event_id}|fm|#{code}" if code.present?
    end

    def normalized(value)
      NicknameMap.normalize(value)
    end
  end
end
