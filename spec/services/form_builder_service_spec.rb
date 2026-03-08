require "rails_helper"

RSpec.describe FormBuilderService do
  describe "#call" do
    it "creates a form with the given name" do
      form = described_class.new(name: "Test Form", sections: %i[person_identifier]).call
      expect(form.name).to eq("Test Form")
    end

    it "stores selected sections on the form" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      expect(form.sections).to eq(%w[person_identifier consent])
    end

    it "sets scholarship_application flag" do
      form = described_class.new(name: "Scholarship", sections: %i[scholarship], scholarship_application: true).call
      expect(form.scholarship_application).to be true
    end

    it "creates fields with sequential positions" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..positions.size).to_a)
    end

    context "person_identifier section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_identifier]).call }

      it "creates first_name, last_name, primary_email, and confirm_email fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("first_name", "last_name", "primary_email", "confirm_email")
      end
    end

    context "person_contact_info section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_contact_info]).call }

      it "creates contact info fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("nickname", "pronouns", "phone", "mailing_city", "agency_name")
      end
    end

    context "scholarship section" do
      let(:form) { described_class.new(name: "Test", sections: %i[scholarship]).call }

      it "creates scholarship fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("scholarship_eligibility", "impact_description", "implementation_plan")
      end
    end

    context "consent section" do
      let(:form) { described_class.new(name: "Test", sections: %i[consent]).call }

      it "creates communication_consent field" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("communication_consent")
      end
    end

    context "event_feedback section" do
      let(:form) { described_class.new(name: "Test", sections: %i[event_feedback]).call }

      it "creates feedback fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("referral_source", "training_motivation", "interested_in_more")
      end
    end

    context "payment section" do
      let(:form) { described_class.new(name: "Test", sections: %i[payment]).call }

      it "creates payment fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("number_of_attendees", "payment_method")
      end
    end

    context "post_event_feedback section" do
      let(:form) { described_class.new(name: "Test", sections: %i[post_event_feedback]).call }

      it "creates post-event feedback fields" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("event_rating", "most_valuable", "improvement_suggestions")
      end
    end

    context "with multiple sections (short event registration)" do
      let(:form) do
        described_class.new(
          name: "Short Event Registration",
          sections: %i[person_identifier consent event_feedback scholarship]
        ).call
      end

      it "creates fields from all selected sections" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include("first_name", "communication_consent", "referral_source", "scholarship_eligibility")
      end

      it "does not include fields from unselected sections" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).not_to include("nickname", "phone", "payment_method")
      end
    end

    context "with multiple sections (extended event registration)" do
      let(:form) do
        described_class.new(
          name: "Extended Event Registration",
          sections: %i[person_identifier person_contact_info person_background professional_info event_feedback scholarship payment consent]
        ).call
      end

      it "creates fields from all 8 sections" do
        keys = form.form_fields.pluck(:field_key).compact
        expect(keys).to include(
          "first_name", "nickname", "racial_ethnic_identity",
          "primary_service_area", "referral_source",
          "scholarship_eligibility", "payment_method", "communication_consent"
        )
      end
    end
  end
end
