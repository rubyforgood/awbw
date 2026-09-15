module PersonServices
  # After a person merge, a kind can still hold redundant licenses the generic
  # (kind, number) collapse leaves behind: an empty-number placeholder alongside a
  # real license of the same kind, or an "" that never matched a nil. Within each
  # kind, fold every blank-number license into a sibling — preferring one with a real
  # number — moving its CE registrations onto the survivor. Left untouched: two
  # different real numbers of the same kind, and licenses of different kinds (a shared
  # number across kinds is allowed). Runs in the people deduper's after_merge.
  class ReconcileProfessionalLicenses
    def initialize(person)
      @person = person
    end

    def call
      @person.professional_licenses.reload.group_by(&:kind).each_value do |licenses|
        blanks, numbered = licenses.partition { |license| license.number.blank? }
        next if blanks.empty?

        survivor = numbered.first || blanks.shift
        (blanks - [ survivor ]).each { |loser| fold(loser, into: survivor) }
      end
    end

    private

    def fold(loser, into:)
      ModelDeduper.new(model_class: ProfessionalLicense, logger: Rails.logger, dry_run: false).merge(into, loser)
    end
  end
end
