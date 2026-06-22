require "rails_helper"

RSpec.describe EventOrganizationLinkStatus do
  let(:event) { create(:event) }
  let(:form) { create(:form) }
  let!(:event_form) { create(:event_form, :registration, event: event, form: form) }
  let!(:agency_field) { create(:form_field, form: form, field_identifier: "agency_name") }

  def submit_agency_name(person, name)
    submission = create(:form_submission, person: person, form: form)
    create(:form_answer, form_submission: submission, form_field: agency_field, submitted_answer: name)
  end

  describe "#registration_ids_for" do
    it "classifies linked, pending, and none registrations" do
      linked = create(:event_registration, event: event)
      organization = create(:organization, name: "Acme Org")
      create(:event_registration_organization, event_registration: linked, organization: organization)

      pending = create(:event_registration, event: event)
      submit_agency_name(pending.registrant, "Unlinked Agency")

      none = create(:event_registration, event: event)

      service = described_class.new(event)

      expect(service.registration_ids_for("linked")).to contain_exactly(linked.id)
      expect(service.registration_ids_for("pending")).to contain_exactly(pending.id)
      expect(service.registration_ids_for("none")).to contain_exactly(none.id)
    end

    it "treats a submitted name matching a linked organization as resolved (not pending)" do
      registration = create(:event_registration, event: event)
      organization = create(:organization, name: "Acme Org")
      create(:event_registration_organization, event_registration: registration, organization: organization)
      submit_agency_name(registration.registrant, "acme org")

      service = described_class.new(event)

      expect(service.registration_ids_for("linked")).to contain_exactly(registration.id)
      expect(service.registration_ids_for("pending")).to be_empty
    end

    it "lists a registration that is both linked and pending under each status" do
      registration = create(:event_registration, event: event)
      organization = create(:organization, name: "Acme Org")
      create(:event_registration_organization, event_registration: registration, organization: organization)
      submit_agency_name(registration.registrant, "A Different Agency")

      service = described_class.new(event)

      expect(service.registration_ids_for("linked")).to contain_exactly(registration.id)
      expect(service.registration_ids_for("pending")).to contain_exactly(registration.id)
      expect(service.registration_ids_for("none")).to be_empty
    end

    it "returns an empty array for an unrecognized status" do
      create(:event_registration, event: event)

      expect(described_class.new(event).registration_ids_for("bogus")).to eq([])
    end
  end
end
