require "rails_helper"

RSpec.describe ScholarshipApplicationFormBuilder do
  let(:event) { create(:event) }

  describe ".build!" do
    subject(:form) { described_class.build!(event) }

    it "creates a form named 'Scholarship Application' on the event" do
      expect(form.name).to eq("Scholarship Application")
      expect(form.owner).to eq(event)
    end

    it "creates all expected form fields" do
      expect(form.form_fields.count).to eq(39)
    end

    it "assigns sequential positions starting at 1" do
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..39).to_a)
    end

    describe "contact fields" do
      it "creates fields in the contact group" do
        contact_fields = form.form_fields.where(field_group: "contact")
        field_keys = contact_fields.where.not(field_key: nil).pluck(:field_key)

        expect(field_keys).to include(
          "first_name", "last_name", "primary_email", "primary_email_type",
          "secondary_email", "secondary_email_type",
          "mailing_street", "mailing_city", "mailing_state", "mailing_zip",
          "mailing_address_type", "phone", "phone_type",
          "racial_ethnic_identity", "referral_source"
        )
      end

      it "creates race/ethnicity as a required checkbox field with 9 options" do
        field = form.form_fields.find_by(field_key: "racial_ethnic_identity")

        expect(field.answer_type).to eq("multiple_choice_checkbox")
        expect(field.is_required).to be true
        expect(field.form_field_answer_options.count).to eq(9)
      end
    end

    describe "agency fields" do
      it "creates fields in the agency group" do
        agency_fields = form.form_fields.where(field_group: "agency")
        field_keys = agency_fields.where.not(field_key: nil).pluck(:field_key)

        expect(field_keys).to include(
          "agency_name", "agency_position", "agency_type",
          "agency_street", "agency_city", "agency_state", "agency_zip",
          "agency_website", "scholarship_eligibility"
        )
      end

      it "creates agency type as radio with 4 options" do
        field = form.form_fields.find_by(field_key: "agency_type")

        expect(field.answer_type).to eq("multiple_choice_radio")
        expect(field.form_field_answer_options.count).to eq(4)
      end

      it "creates scholarship eligibility as a required checkbox" do
        field = form.form_fields.find_by(field_key: "scholarship_eligibility")

        expect(field.answer_type).to eq("multiple_choice_checkbox")
        expect(field.is_required).to be true
      end
    end

    describe "service fields" do
      it "creates primary service area as radio with 18 options" do
        field = form.form_fields.find_by(field_key: "primary_service_area")

        expect(field.answer_type).to eq("multiple_choice_radio")
        expect(field.is_required).to be true
        expect(field.form_field_answer_options.count).to eq(18)
      end

      it "creates workshop settings as checkbox with 14 options" do
        field = form.form_fields.find_by(field_key: "workshop_settings")

        expect(field.answer_type).to eq("multiple_choice_checkbox")
        expect(field.form_field_answer_options.count).to eq(14)
      end
    end

    describe "participant fields" do
      it "creates life experiences as checkbox with 29 options" do
        field = form.form_fields.find_by(field_key: "client_life_experiences")

        expect(field.answer_type).to eq("multiple_choice_checkbox")
        expect(field.form_field_answer_options.count).to eq(29)
      end

      it "creates primary age group as radio with 6 options" do
        field = form.form_fields.find_by(field_key: "primary_age_group")

        expect(field.answer_type).to eq("multiple_choice_radio")
        expect(field.form_field_answer_options.count).to eq(6)
      end

      it "creates training motivation as checkbox with 10 options" do
        field = form.form_fields.find_by(field_key: "training_motivation")

        expect(field.answer_type).to eq("multiple_choice_checkbox")
        expect(field.form_field_answer_options.count).to eq(10)
      end
    end

    describe "goals fields" do
      it "creates required paragraph fields for impact and implementation" do
        impact = form.form_fields.find_by(field_key: "impact_description")
        implementation = form.form_fields.find_by(field_key: "implementation_plan")

        expect(impact.answer_type).to eq("free_form_input_paragraph")
        expect(impact.is_required).to be true
        expect(implementation.answer_type).to eq("free_form_input_paragraph")
        expect(implementation.is_required).to be true
      end

      it "creates an optional additional comments field" do
        field = form.form_fields.find_by(field_key: "additional_comments")

        expect(field.answer_type).to eq("free_form_input_paragraph")
        expect(field.is_required).to be false
      end
    end

    describe "group headers" do
      it "creates headers for each section" do
        headers = form.form_fields.where(answer_type: :group_header).pluck(:question)

        expect(headers).to contain_exactly(
          "Your Information",
          "Primary Mailing Address",
          "Agency Information",
          "Agency Address",
          "Service Areas & Settings",
          "Participant Information",
          "Your Goals"
        )
      end
    end
  end
end
