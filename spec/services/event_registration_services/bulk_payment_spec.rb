require "rails_helper"

RSpec.describe EventRegistrationServices::BulkPayment do
  let(:event) { create(:event, :published, :publicly_visible) }
  let(:form) do
    f = FormBuilderService.new(name: "Bulk Payment", sections: %i[bulk_payment], role: "bulk_payment").call
    event.event_forms.create!(form: f, role: "bulk_payment")
    f
  end

  def field_id(key)
    form.form_fields.find_by!(field_identifier: key).id.to_s
  end

  def base_form_params(overrides = {})
    {
      field_id("payer_first_name") => "Pat",
      field_id("payer_last_name") => "Payer",
      field_id("payer_email") => "pat@example.com",
      field_id("payment_method") => "Check",
      field_id("number_of_attendees") => "3"
    }.merge(overrides)
  end

  describe "payer phone" do
    it "stores the payer phone as a primary phone contact method on the person" do
      result = described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(field_id("payer_phone") => "555-123-4567")
      )

      expect(result.success?).to be true
      person = result.form_submission.person
      contact = person.contact_methods.find_by(kind: :phone)
      expect(contact).to have_attributes(value: "555-123-4567", primary: true)
      expect(person.phone_number).to eq("555-123-4567")
    end

    it "does not create a phone contact when no payer phone is given" do
      result = described_class.call(
        event: event,
        form: form,
        form_params: base_form_params
      )

      expect(result.success?).to be true
      expect(result.form_submission.person.contact_methods.where(kind: :phone)).to be_empty
    end
  end

  describe "logged-in payer" do
    let(:person) do
      create(:person, first_name: "Logged", last_name: "In",
             user: create(:user, email: "logged.in@example.com"))
    end

    # Logged-in payers don't see the logged_out_only payer fields, so those keys
    # never reach @form_params. Without a backfill the payer's email/name would be
    # missing from the saved form answers even though we know who they are.
    def answer(submission, key)
      field = form.form_fields.find_by!(field_identifier: key)
      submission.form_answers.find_by(form_field: field)&.submitted_answer
    end

    it "saves the payer's email, name, phone, and organization from their profile" do
      person.contact_methods.create!(kind: :phone, value: "555-987-6543", primary: true)
      # Facilitator org wins even though a non-facilitator affiliation is more recent.
      person.affiliations.create!(organization: create(:organization, name: "Acme Co"), title: "Facilitator")
      person.affiliations.create!(organization: create(:organization, name: "Other Org"), title: "Member")

      result = described_class.call(
        event: event,
        form: form,
        form_params: {
          field_id("payment_method") => "Check",
          field_id("number_of_attendees") => "3"
        },
        person: person
      )

      expect(result.success?).to be true
      submission = result.form_submission
      expect(answer(submission, "payer_email")).to eq("logged.in@example.com")
      expect(answer(submission, "payer_first_name")).to eq("Logged")
      expect(answer(submission, "payer_last_name")).to eq("In")
      expect(answer(submission, "payer_phone")).to eq("555-987-6543")
      expect(answer(submission, "payer_organization")).to eq("Acme Co")
    end

    it "falls back to the most recent active org when the payer has no facilitator affiliation" do
      person.affiliations.create!(organization: create(:organization, name: "Older Org"),
                                  title: "Member", updated_at: 2.days.ago)
      person.affiliations.create!(organization: create(:organization, name: "Newer Org"),
                                  title: "Member", updated_at: 1.day.ago)

      result = described_class.call(
        event: event,
        form: form,
        form_params: {
          field_id("payment_method") => "Check",
          field_id("number_of_attendees") => "3"
        },
        person: person
      )

      expect(answer(result.form_submission, "payer_organization")).to eq("Newer Org")
    end

    it "does not rewrite the payer's existing phone contact when backfilling" do
      contact = person.contact_methods.create!(
        kind: :phone, value: "555-987-6543", primary: true, contact_type: "work"
      )

      described_class.call(
        event: event,
        form: form,
        form_params: {
          field_id("payment_method") => "Check",
          field_id("number_of_attendees") => "3"
        },
        person: person
      )

      expect(contact.reload).to have_attributes(contact_type: "work", value: "555-987-6543")
      expect(person.contact_methods.where(kind: :phone).count).to eq(1)
    end

    it "does not overwrite a payer field that was submitted" do
      result = described_class.call(
        event: event,
        form: form,
        form_params: {
          field_id("payer_email") => "typed@example.com",
          field_id("payment_method") => "Check",
          field_id("number_of_attendees") => "3"
        },
        person: person
      )

      expect(answer(result.form_submission, "payer_email")).to eq("typed@example.com")
    end
  end

  describe "notifications" do
    it "sends the payer confirmation and the staff FYI" do
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :bulk_payment_confirmation, recipient_role: :person)
      )
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :bulk_payment_confirmation_fyi, recipient_role: :admin)
      )

      described_class.call(event: event, form: form, form_params: base_form_params)
    end
  end
end
