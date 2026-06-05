require "rails_helper"

RSpec.describe EventRegistrationServices::PublicRegistration do
  let(:event) { create(:event, :published, :publicly_visible) }
  let(:form) do
    f = FormBuilderService.new(
      name: FormBuilderService::EXTENDED_REGISTRATION_FORM_NAME,
      sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
    ).call
    event.event_forms.create!(form: f, role: "registration")
    f
  end

  def field_id(key)
    form.form_fields.find_by!(field_identifier: key).id.to_s
  end

  def base_form_params(first_name:, last_name:, email:)
    {
      field_id("first_name") => first_name,
      field_id("last_name") => last_name,
      field_id("primary_email") => email,
      field_id("primary_email_type") => "personal"
    }
  end

  describe "re-registration after cancellation" do
    let(:person) { create(:person, first_name: "Jane", last_name: "Doe", email: "jane@example.com") }
    let!(:cancelled_registration) do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
    end

    it "reactivates a cancelled registration" do
      result = described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )

      expect(result.success?).to be true
      expect(result.event_registration).to eq(cancelled_registration)
      expect(cancelled_registration.reload.status).to eq("registered")
    end

    it "sends confirmation and FYI notifications on re-registration" do
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :event_registration_confirmation, recipient_role: :person)
      )
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: :event_registration_confirmation_fyi, recipient_role: :admin)
      )

      described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )
    end

    it "does not send notifications for an already-active registration" do
      cancelled_registration.update!(status: "registered")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(first_name: "Jane", last_name: "Doe", email: "jane@example.com")
      )
    end
  end
end
