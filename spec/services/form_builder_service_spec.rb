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

    it "sets role flag" do
      form = described_class.new(name: "Scholarship", sections: %i[scholarship], role: "scholarship").call
      expect(form.role).to eq "scholarship"
    end

    it "creates fields with sequential positions" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..positions.size).to_a)
    end

    context "person_identifier section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_identifier]).call }

      it "creates first_name, last_name, primary_email, and confirm_email fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("first_name", "last_name", "primary_email", "confirm_email")
      end
    end

    context "person_contact_info section" do
      let(:form) { described_class.new(name: "Test", sections: %i[person_contact_info]).call }

      it "creates contact info fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("nickname", "pronouns", "phone", "mailing_city", "agency_name")
      end
    end

    context "scholarship section" do
      let(:form) { described_class.new(name: "Test", sections: %i[scholarship]).call }

      it "creates scholarship fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("scholarship_eligibility", "impact_description", "implementation_plan")
      end
    end

    context "consent section" do
      let(:form) { described_class.new(name: "Test", sections: %i[consent]).call }

      it "creates communication_consent field" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("communication_consent")
      end
    end

    context "payment section" do
      let(:form) { described_class.new(name: "Test", sections: %i[payment]).call }

      it "creates payment fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("payment_method")
      end
    end

    context "marketing section" do
      let(:form) { described_class.new(name: "Test", sections: %i[marketing]).call }

      it "creates marketing fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("referral_source", "training_motivation", "interested_in_more")
      end
    end

    context "post_event_feedback section" do
      let(:form) { described_class.new(name: "Test", sections: %i[post_event_feedback]).call }

      it "creates post-event feedback fields" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("event_rating", "most_valuable", "improvement_suggestions")
      end
    end

    context "with multiple sections (short event registration)" do
      let(:form) do
        described_class.new(
          name: "Short Event Registration",
          sections: %i[person_identifier consent marketing scholarship]
        ).call
      end

      it "creates fields from all selected sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include("first_name", "communication_consent", "referral_source", "scholarship_eligibility")
      end

      it "does not include fields from unselected sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).not_to include("nickname", "phone", "payment_method")
      end
    end

    context "with multiple sections (extended event registration)" do
      let(:form) do
        described_class.new(
          name: "Extended Event Registration",
          sections: %i[person_identifier person_contact_info person_background professional_info marketing scholarship payment consent]
        ).call
      end

      it "creates fields from all sections" do
        keys = form.form_fields.pluck(:field_identifier).compact
        expect(keys).to include(
          "first_name", "nickname", "racial_ethnic_identity",
          "primary_service_area", "referral_source",
          "scholarship_eligibility", "payment_method", "communication_consent"
        )
      end
    end
  end

  describe ".update_sections!" do
    it "adds new sections and their fields" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      initial_count = form.form_fields.count

      described_class.update_sections!(form, %i[person_identifier consent])

      form.reload
      expect(form.sections).to eq(%w[person_identifier consent])
      expect(form.form_fields.count).to be > initial_count
      expect(form.form_fields.pluck(:field_identifier).compact).to include("communication_consent")
    end

    it "removes unchecked sections and their fields" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      expect(form.form_fields.where(section: "consent").count).to be > 0

      described_class.update_sections!(form, %i[person_identifier])

      form.reload
      expect(form.sections).to eq(%w[person_identifier])
      expect(form.form_fields.where(section: "consent")).to be_empty
    end

    it "removes section headers when a section is removed" do
      form = described_class.new(name: "Test", sections: %i[person_identifier scholarship]).call
      expect(form.form_fields.where(answer_type: :group_header, name: "Scholarship Application")).to exist

      described_class.update_sections!(form, %i[person_identifier])

      form.reload
      expect(form.form_fields.where(answer_type: :group_header, name: "Scholarship Application")).not_to exist
    end

    it "preserves existing fields when sections are unchanged" do
      form = described_class.new(name: "Test", sections: %i[person_identifier consent]).call
      original_ids = form.form_fields.pluck(:id).sort

      described_class.update_sections!(form, %i[person_identifier consent])

      form.reload
      expect(form.form_fields.pluck(:id).sort).to eq(original_ids)
    end

    it "appends new fields after existing ones" do
      form = described_class.new(name: "Test", sections: %i[person_identifier]).call
      max_before = form.form_fields.maximum(:position)

      described_class.update_sections!(form, %i[person_identifier consent])

      new_fields = form.form_fields.where(section: "consent")
      expect(new_fields.minimum(:position)).to be > max_before
    end
  end
end
