require "rails_helper"

RSpec.describe EventRegistrationServices::PublicRegistration do
  let(:event) { create(:event, :published, :publicly_visible) }
  let(:form) do
    f = FormBuilderService.new(
      name: "Extended Event Registration",
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

  describe "primary service area tagging" do
    let!(:primary_sector) { create(:sector, name: "Healthcare") }
    let!(:other_sector) { create(:sector, name: "Education") }

    it "tags the selected primary service area sectors as primary on the person" do
      result = described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
          field_id("primary_service_area") => [ primary_sector.id.to_s ]
        )
      )

      expect(result.success?).to be true
      person = result.event_registration.registrant
      primary_item = person.sectorable_items.find_by(sector: primary_sector)
      expect(primary_item.is_primary).to be true
    end

    it "marks an existing additional sector as primary when later selected" do
      person = create(:person, first_name: "Pat", last_name: "Lee", email: "pat@example.com")
      person.sectorable_items.create!(sector: primary_sector, is_primary: false)

      described_class.call(
        event: event,
        form: form,
        form_params: base_form_params(first_name: "Pat", last_name: "Lee", email: "pat@example.com").merge(
          field_id("primary_service_area") => [ primary_sector.id.to_s ]
        )
      )

      expect(person.sectorable_items.find_by(sector: primary_sector).is_primary).to be true
    end
  end

  describe "CE credit interest (magic question)" do
    let!(:ce_field) do
      field = form.form_fields.create!(
        name: "Might you be seeking continuing education (CE) hours for attending this training?",
        answer_type: :single_select_radio,
        status: :active,
        position: (form.form_fields.maximum(:position) || 0) + 1,
        required: false,
        field_identifier: described_class::CE_CREDIT_INTEREST_IDENTIFIER,
        section: "continuing_education",
        visibility: :always_ask
      )
      %w[Yes No].each_with_index do |opt, idx|
        ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
        field.form_field_answer_options.create!(answer_option: ao)
      end
      field
    end

    def register_with_ce(answer)
      params = base_form_params(first_name: "Cy", last_name: "Reed", email: "cy@example.com")
      params = params.merge(ce_field.id.to_s => answer) unless answer.nil?
      described_class.call(event: event, form: form, form_params: params)
    end

    it "toggles ce_credit_requested on when answered Yes" do
      result = register_with_ce("Yes")
      expect(result.event_registration.ce_credit_requested).to be true
    end

    it "leaves ce_credit_requested off when answered No" do
      result = register_with_ce("No")
      expect(result.event_registration.ce_credit_requested).to be false
    end

    it "leaves ce_credit_requested off when unanswered" do
      result = register_with_ce(nil)
      expect(result.event_registration.ce_credit_requested).to be false
    end

    it "toggles ce_credit_requested on for an existing registration that answers Yes" do
      person = create(:person, first_name: "Cy", last_name: "Reed", email: "cy@example.com")
      existing = create(:event_registration, event: event, registrant: person, ce_credit_requested: false)

      result = register_with_ce("Yes")

      expect(result.event_registration).to eq(existing)
      expect(existing.reload.ce_credit_requested).to be true
    end
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
