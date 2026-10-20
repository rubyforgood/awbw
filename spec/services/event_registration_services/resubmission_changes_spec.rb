require "rails_helper"

RSpec.describe EventRegistrationServices::ResubmissionChanges do
  let(:unchanged) do
    { scholarship_requested: false, ce_requested: false, w9_requested: false, invoice_requested: false,
      expected_payment_method: "Check", someone_else_will_pay: false, organization_ids: [] }
  end

  describe ".snapshot" do
    it "captures the registration's resubmittable state" do
      registration = create(:event_registration, scholarship_requested: true, w9_requested: true,
                                                 expected_payment_method: "Check")
      organization = create(:organization)
      registration.event_registration_organizations.create!(organization: organization)

      expect(described_class.snapshot(registration)).to eq(
        scholarship_requested: true, ce_requested: false, w9_requested: true, invoice_requested: false,
        expected_payment_method: "Check", someone_else_will_pay: false, organization_ids: [ organization.id ]
      )
    end
  end

  describe ".between" do
    it "has no notes when nothing changed" do
      expect(described_class.between(unchanged, unchanged).notes).to be_empty
    end

    it "notes every newly requested item" do
      after = unchanged.merge(scholarship_requested: true, ce_requested: true, w9_requested: true, invoice_requested: true)

      expect(described_class.between(unchanged, after).notes).to eq([
        "Scholarship now requested",
        "Continuing education credit now requested",
        "W-9 now requested",
        "Invoice now requested"
      ])
    end

    it "notes a payment method change, including one set for the first time" do
      expect(described_class.between(unchanged, unchanged.merge(expected_payment_method: "Credit card")).notes)
        .to eq([ "Payment method changed from Check to Credit card" ])
      expect(described_class.between(unchanged.merge(expected_payment_method: nil), unchanged).notes)
        .to eq([ "Payment method changed from none to Check" ])
    end

    it "notes who's paying in either direction" do
      paying = unchanged.merge(someone_else_will_pay: true)

      expect(described_class.between(unchanged, paying).notes).to eq([ "Someone else will now pay" ])
      expect(described_class.between(paying, unchanged).notes).to eq([ "Someone else is no longer paying" ])
    end

    it "notes a newly linked organization" do
      kept = create(:organization, name: "Kept Org")
      added = create(:organization, name: "Helping Hands")
      before = unchanged.merge(organization_ids: [ kept.id ])
      after = unchanged.merge(organization_ids: [ kept.id, added.id ])

      expect(described_class.between(before, after).notes).to eq([ "Organization linked: Helping Hands" ])
    end

    context "with a submission" do
      let(:person) { create(:person) }
      let(:event) { create(:event) }
      let(:form) { create(:form) }
      let(:city) { create(:form_field, form: form, name: "City", field_identifier: "city") }
      let(:pronouns) { create(:form_field, form: form, name: "Pronouns", field_identifier: "pronouns") }
      let(:bio) { create(:form_field, form: form, name: "Bio", field_identifier: "bio") }
      let(:payment) { create(:form_field, form: form, name: "How will you pay?", field_identifier: "payment_method") }

      def submit(answers)
        submission = FormSubmission.create!(person: person, form: form, event: event, role: "registration")
        answers.each { |field, value| submission.persist_answer(field, value) }
        submission
      end

      it "notes each answer that differs from the previous submission" do
        submit(city => "Oakland", bio => "Teacher", payment => "Check")
        latest = submit(city => "Berkeley", pronouns => "she/her", bio => "Teacher", payment => "Credit card")

        expect(described_class.between(unchanged, unchanged, submission: latest).notes).to eq([
          "City: changed from Oakland to Berkeley",
          "Pronouns: added she/her"
        ])
      end

      it "skips answers left out of the resubmission and squishes multi-line ones" do
        submit(city => "Oakland", bio => "Teacher")
        latest = submit(bio => "Teacher\nand artist")

        expect(described_class.between(unchanged, unchanged, submission: latest).notes)
          .to eq([ "Bio: changed from Teacher to Teacher and artist" ])
      end

      it "has no answer notes for a first submission" do
        latest = submit(city => "Oakland")

        expect(described_class.between(unchanged, unchanged, submission: latest).notes).to be_empty
      end

      it "notes a change to one per-resource copy of a fanned-out question" do
        clarity = create(:form_field, form: form, name: "How clear was", answer_type: :single_select_radio)
        masks = create(:resource, title: "Masks")
        collage = create(:resource, title: "Collage")
        create(:form_field_resource, form_field: clarity, resource: masks)
        create(:form_field_resource, form_field: clarity, resource: collage)
        submit(clarity => { masks.id.to_s => "Yes", collage.id.to_s => "Yes" })
        latest = submit(clarity => { masks.id.to_s => "No", collage.id.to_s => "Yes" })

        expect(described_class.between(unchanged, unchanged, submission: latest).notes)
          .to eq([ "How clear was Masks: changed from Yes to No" ])
      end
    end
  end

  describe "#subject_suffix" do
    it "calls out a scholarship request first" do
      changes = described_class.new([ "W-9 now requested", described_class::SCHOLARSHIP_REQUESTED ])

      expect(changes.subject_suffix).to eq(" (scholarship now requested)")
    end

    it "flags any other change generically" do
      expect(described_class.new([ "W-9 now requested" ]).subject_suffix).to eq(" (registration changed)")
    end

    it "is nil with no changes" do
      expect(described_class.new([]).subject_suffix).to be_nil
    end
  end

  it "round-trips notes through the notification message" do
    changes = described_class.new([ "W-9 now requested", "Invoice now requested" ])

    expect(described_class.from_message(changes.to_message).notes).to eq(changes.notes)
    expect(described_class.new([]).to_message).to be_nil
  end
end
