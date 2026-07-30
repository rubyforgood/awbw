require "rails_helper"

RSpec.describe FormSubmission do
  describe "associations" do
    it { should belong_to(:person) }
    it { should belong_to(:form) }
    it { should belong_to(:event).optional }
    it { should have_many(:form_answers).dependent(:destroy) }
    it { should accept_nested_attributes_for(:form_answers) }
  end

  describe "slug" do
    it "generates a unique slug for bulk payment submissions" do
      submission = create(:form_submission, role: "bulk_payment")

      expect(submission.slug).to be_present
    end

    it "leaves the slug blank for other submission roles" do
      submission = create(:form_submission, role: "registration")

      expect(submission.slug).to be_nil
    end
  end

  describe "#answers_by_identifier" do
    it "maps submitted answers by their field identifier" do
      form = create(:form)
      field = create(:form_field, form: form, field_identifier: "payer_email", name: "Payer email")
      submission = create(:form_submission, form: form)
      submission.form_answers.create!(form_field: field, submitted_answer: "pat@example.com")

      expect(submission.answers_by_identifier["payer_email"]).to eq("pat@example.com")
    end
  end

  describe "#bulk_payment_attendees" do
    let(:form) { create(:form) }
    let(:field) { create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees") }
    let(:submission) { create(:form_submission, form: form) }

    it "parses the attendees JSON array" do
      submission.form_answers.create!(form_field: field, submitted_answer: [ { first_name: "A", email: "a@example.com" } ].to_json)

      expect(submission.bulk_payment_attendees).to eq([ { "first_name" => "A", "email" => "a@example.com" } ])
    end

    it "returns an empty array for invalid JSON" do
      submission.form_answers.create!(form_field: field, submitted_answer: "not json")

      expect(submission.bulk_payment_attendees).to eq([])
    end
  end

  describe "#bulk_payment_amount_cents" do
    let(:event) { create(:event, cost_cents: 2500) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form) }

    it "multiplies the event cost by the number of attendees submitted" do
      field = create(:form_field, form: form, field_identifier: "number_of_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field, submitted_answer: "3")

      expect(submission.bulk_payment_amount_cents(event)).to eq(7500)
    end

    it "falls back to the count of submitted attendees when no count is given" do
      field = create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field,
                                      submitted_answer: [ { first_name: "A" }, { first_name: "B" } ].to_json)

      expect(submission.bulk_payment_amount_cents(event)).to eq(5000)
    end

    it "returns zero when the event has no cost" do
      free_event = create(:event, cost_cents: 0)
      field = create(:form_field, form: form, field_identifier: "number_of_attendees", name: "Attendees")
      submission.form_answers.create!(form_field: field, submitted_answer: "3")

      expect(submission.bulk_payment_amount_cents(free_event)).to eq(0)
    end
  end

  describe "#bulk_payment_receipt_available?" do
    let(:submission) { create(:form_submission, role: "bulk_payment") }

    it "is true once a payment is recorded" do
      create(:payment, form_submission: submission)

      expect(submission.reload.bulk_payment_receipt_available?).to be(true)
    end

    it "is false while no payment is on file" do
      expect(submission.bulk_payment_receipt_available?).to be(false)
    end

    it "is false for a non-bulk-payment submission even with a payment" do
      other = create(:form_submission, role: "registration")
      create(:payment, form_submission: other)

      expect(other.reload.bulk_payment_receipt_available?).to be(false)
    end
  end

  describe "linked registrations" do
    let(:event) { create(:event) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form, event: event) }
    let!(:reg1) { create(:event_registration, event: event) }
    let!(:reg2) { create(:event_registration, event: event) }

    describe "#linked_registration_ids" do
      it "returns an empty array when metadata is nil" do
        expect(submission.linked_registration_ids).to eq([])
      end

      it "returns an empty array when metadata has no linked_registration_ids" do
        submission.update!(metadata: { "other_key" => "value" })
        expect(submission.linked_registration_ids).to eq([])
      end

      it "returns the stored ids" do
        submission.update!(metadata: { "linked_registration_ids" => [ reg1.id, reg2.id ] })
        expect(submission.linked_registration_ids).to contain_exactly(reg1.id, reg2.id)
      end
    end

    describe "#link_registration!" do
      it "adds a registration id to metadata" do
        submission.link_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end

      it "does not duplicate an existing id" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end

      it "preserves other metadata" do
        submission.update!(metadata: { "other_key" => "value" })
        submission.link_registration!(reg1.id)

        expect(submission.reload.metadata["other_key"]).to eq("value")
        expect(submission.linked_registration_ids).to eq([ reg1.id ])
      end
    end

    describe "#unlink_registration!" do
      it "removes a registration id from metadata" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg2.id)
        submission.unlink_registration!(reg1.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg2.id ])
      end

      it "is a no-op when the id is not linked" do
        submission.link_registration!(reg1.id)
        submission.unlink_registration!(reg2.id)

        expect(submission.reload.linked_registration_ids).to eq([ reg1.id ])
      end
    end

    describe "#linked_registrations" do
      it "returns event registrations matching linked ids" do
        submission.link_registration!(reg1.id)
        submission.link_registration!(reg2.id)

        expect(submission.linked_registrations).to contain_exactly(reg1, reg2)
      end

      it "returns empty relation when nothing is linked" do
        expect(submission.linked_registrations).to be_empty
      end
    end
  end
end
