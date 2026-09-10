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
      @registration.continuing_education_registrations.each do |ce|
        license = ce.professional_license
        next if license.person_id == registrant.id

        equivalent = ProfessionalLicense.find_or_create_for(person: registrant, number: license.number, kind: license.kind)
        # update_columns: the repoint makes the record valid again, and skips the
        # cost_not_below_allocations check so an already-over-allocated CE (allowed;
        # flagged in the UI) doesn't block the repair.
        ce.update_columns(professional_license_id: equivalent.id)
      end
    end
  end
end
