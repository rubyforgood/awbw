require "rails_helper"

RSpec.describe RegistrantCeForm do
  let(:event) { create(:event, :ended) }
  let(:registration) { create(:event_registration, event:) }
  let(:form) { create(:form, name: "CE Evaluation", anonymous: true) }
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

    it "is true once the registrant has submitted, though no submission is theirs" do
      EventRegistrationServices::CalloutFormSubmission.call(registration:, callout:, form:,
        form_params: { required_field.id.to_s => "Great" })

      ce_form = described_class.new(registration)
      expect(ce_form.submission).to be_nil
      expect(ce_form).to be_complete
      expect(ce_form).to be_completed_anonymously
    end

    it "is not completed anonymously before they submit" do
      expect(described_class.new(registration)).not_to be_completed_anonymously
    end

    it "is not satisfied by someone else's completion" do
      create(:form_completion, form:, event:)

      expect(described_class.new(registration)).not_to be_complete
    end

    it "never matches others' anonymous submissions for the unsaved sample registrant" do
      create(:form_submission, person: nil, form:, event:)
      sample = SampleTicketRegistration.new(event, all_options: true).registration

      expect(described_class.new(sample).submission).to be_nil
      expect(described_class.new(sample)).not_to be_complete
    end

    it "still finds the submission after the form's role changes" do
      EventRegistrationServices::CalloutFormSubmission.call(registration:, callout:, form:,
        form_params: { required_field.id.to_s => "Great" })
      form.update!(role: "general")
      expect(described_class.new(registration)).to be_complete
    end

    context "with a required fanned-out field" do
      let(:clarity) { create(:form_field, form:, name: "How clear was", answer_type: :single_select_radio, required: true) }
      let(:masks) { create(:resource, title: "Masks") }
      let(:collage) { create(:resource, title: "Collage") }

      before do
        create(:form_field_resource, form_field: clarity, resource: masks)
        create(:form_field_resource, form_field: clarity, resource: collage)
        %w[Yes No].each { |name| create(:form_field_answer_option, form_field: clarity, answer_option: create(:answer_option, name:)) }
      end

      def submit(per_resource)
        EventRegistrationServices::CalloutFormSubmission.call(registration:, callout:, form: form.reload,
          form_params: { required_field.id.to_s => "Great", clarity.id.to_s => per_resource })
      end

      it "is true once every resource's copy is answered" do
        submit(masks.id.to_s => "Yes", collage.id.to_s => "No")
        expect(described_class.new(registration)).to be_complete
      end

      it "is false while one resource's copy is unanswered" do
        submit(masks.id.to_s => "Yes")
        expect(described_class.new(registration)).not_to be_complete
      end
    end
  end
end
