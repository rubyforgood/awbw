require "rails_helper"

RSpec.describe RegistrantCeForm do
  let(:event) { create(:event, :ended) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "CE Evaluation") }
  let!(:required_field) { create(:form_field, form:, name: "How was it?", required: true) }
  let(:callout) { create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours", form:) }

  subject(:ce_form) { described_class.new(registration) }

  before { callout }

  describe "#form" do
    it "returns the form attached to the CE callout" do
      expect(ce_form.form).to eq(form)
    end

    it "is nil when the CE callout has no form" do
      callout.forms.destroy_all
      expect(described_class.new(registration).form).to be_nil
    end

    it "is nil when there is no CE callout" do
      callout.destroy!
      expect(described_class.new(registration).form).to be_nil
    end
  end

  describe "#present?" do
    it "is true when the form has an answerable field" do
      expect(ce_form).to be_present
    end

    it "is false when the form has only a section header" do
      required_field.destroy!
      create(:form_field, form:, answer_type: :group_header)
      expect(described_class.new(registration)).not_to be_present
    end
  end

  describe "#available?" do
    it "is true once the event has ended with no open attendance entry" do
      expect(ce_form).to be_available
    end

    it "is false while an attendance entry is still open" do
      registration.event_attendance_time_entries.create!(signed_in_at: 13.days.ago)
      expect(described_class.new(registration.reload)).not_to be_available
    end

    it "is false before the event has ended" do
      upcoming = create(:event_registration, event: create(:event))
      create(:registration_ticket_callout, event: upcoming.event, builtin_key: "ce_hours", title: "CE hours", form:)
      expect(described_class.new(upcoming)).not_to be_available
    end
  end

  describe "#complete?" do
    it "is false with no submission" do
      expect(ce_form).not_to be_complete
    end

    it "is false when a required field is unanswered" do
      EventRegistrationServices::CalloutFormSubmission.call(registration:, callout:, form:, form_params: {})
      expect(described_class.new(registration)).not_to be_complete
    end

    it "is true when every required field is answered" do
      EventRegistrationServices::CalloutFormSubmission.call(registration:, callout:, form:,
        form_params: { required_field.id.to_s => "Great" })
      expect(described_class.new(registration)).to be_complete
    end
  end
end
