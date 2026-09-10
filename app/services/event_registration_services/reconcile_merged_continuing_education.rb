module EventRegistrationServices
  # After two duplicate registrations for one event are merged, the deleted
  # registration's CE registrations have moved onto the keeper — but they still
  # point at the deleted registrant's license, so they're invalid (the license
  # belongs to the other person) and duplicate the keeper's own CE for the same
  # enrollment. Repoint each to the kept registrant's equivalent license (same kind
  # + number, found or created), then fold the resulting duplicates into one with
  # ContinuingEducationDeduper so payments are preserved and nothing is billed twice.
  class ReconcileMergedContinuingEducation
    def initialize(registration)
      @registration = registration
    end

    def call
      relicense_to_registrant
      ContinuingEducationDeduper.new(@registration.continuing_education_registrations.reload.to_a).call
    end

    private

    def relicense_to_registrant
      registrant = @registration.registrant
      held = registrant.professional_licenses.reload.to_a

      @registration.continuing_education_registrations.each do |ce|
        license = ce.professional_license
        next if license.person_id == registrant.id

        equivalent = held.find { |candidate| same_license?(candidate, license) }
        unless equivalent
          equivalent = ProfessionalLicense.find_or_create_for(person: registrant, number: license.number, kind: license.kind)
          held << equivalent
        end
        # update_columns: the repoint makes the record valid again and skips the
        # cost_not_below_allocations check, so it applies even to an already
        # over-allocated CE (allowed; flagged in the UI).
        ce.update_columns(professional_license_id: equivalent.id)
      end
    end

    # Licenses are identified by kind + number, and a blank number means the same
    # "none on file" whether it's stored as nil or "" — a legacy placeholder can be
    # either, and the two must land on one license.
    def same_license?(candidate, license)
      candidate.kind.presence == license.kind.presence &&
        candidate.number.presence == license.number.presence
    end
  end
end
