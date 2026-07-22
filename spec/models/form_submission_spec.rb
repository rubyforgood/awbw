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

  describe "invoice view tracking" do
    let(:submission) { create(:form_submission, role: "bulk_payment") }

    def view_invoice(submission, viewer_role: "recipient")
      create(
        :ahoy_event,
        name: FormSubmission::INVOICE_VIEW_EVENT,
        properties: { resource_type: "FormSubmission", resource_id: submission.id, viewer_role: viewer_role }
      )
    end

    it "counts recipient opens but ignores admin previews" do
      expect(submission.invoice_viewed?).to be(false)

      view_invoice(submission, viewer_role: "admin")
      expect(submission.invoice_viewed?).to be(false)

      view_invoice(submission)
      expect(submission.invoice_viewed?).to be(true)
    end

    it "returns recipient view times oldest first" do
      travel_to(2.days.ago) { view_invoice(submission) }
      travel_to(1.hour.ago) { view_invoice(submission) }

      times = submission.invoice_view_times
      expect(times.size).to eq(2)
      expect(times.first).to be_within(1.second).of(2.days.ago)
      expect(times.last).to be_within(1.second).of(1.hour.ago)
    end
  end
end
