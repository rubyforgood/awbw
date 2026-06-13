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
