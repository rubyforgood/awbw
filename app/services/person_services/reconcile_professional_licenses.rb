module PersonServices
  # After a person merge, a kind can still hold redundant licenses the generic
  # (kind, number) collapse leaves behind: an empty-number placeholder alongside a
  # real license of the same kind, or an "" that never matched a nil. Within each
  # kind, merge every blank-number license into a sibling — preferring one with a real
  # number — moving its CE registrations onto the survivor. A license type typed into
  # the number ("LMFT 42111") is split out first. A placeholder with no kind
  # either then folds into the person's only real license. Left untouched: two
  # different real numbers of the same kind, and licenses of different kinds (a shared
  # number across kinds is allowed). Runs in the people and event registration
  # dedupers' after_merge.
  class ReconcileProfessionalLicenses
    def initialize(person)
      @person = person
    end

    def call
      split_typed_kinds
      @person.professional_licenses.reload.group_by(&:kind).each_value do |licenses|
        blanks, numbered = licenses.partition { |license| license.number.blank? }
        next if blanks.empty?

        survivor = numbered.first || blanks.shift
        (blanks - [ survivor ]).each { |loser| merge(loser, into: survivor) }
      end
      fold_untyped_placeholders
    end

    private

    # "LMFT 42111" stored as a number with no kind: move the type into the kind, or
    # merge into the person's license that already holds that kind + number.
    def split_typed_kinds
      @person.professional_licenses.reload.each do |license|
        kind, number = ProfessionalLicense.split_kind_from_number(kind: license.kind, number: license.number)
        next if kind == license.kind

        match = @person.professional_licenses.where(kind: kind, number: number).where.not(id: license.id).first
        match ? merge(license, into: match) : license.update!(kind: kind, number: number)
      end
    end

    # A placeholder with no kind and no number names no license of its own, so it is
    # the one real license when the person holds exactly one.
    def fold_untyped_placeholders
      licenses = @person.professional_licenses.reload.to_a
      numbered = licenses.select { |license| license.number.present? }
      return unless numbered.one?

      licenses.select { |license| license.number.blank? && license.kind.blank? }
        .each { |placeholder| merge(placeholder, into: numbered.first) }
    end

    def merge(loser, into:)
      ModelDeduper.new(model_class: ProfessionalLicense, logger: Rails.logger, dry_run: false).merge(into, loser)
    end
  end
end
