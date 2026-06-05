require "rails_helper"

RSpec.describe ShortEventRegistrationFormBuilder do
  let(:event) { create(:event) }

  describe ".build!" do
    subject(:form) { described_class.build!(event) }

    it "creates a registration form linked to the event" do
      expect(form.name).to eq("Short Event Registration")
      expect(event.registration_form).to eq(form)
    end

    it "assigns sequential positions starting at 1" do
      field_count = form.form_fields.count
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..field_count).to_a)
    end

    it "inherits basic contact fields from BaseRegistrationFormBuilder" do
      %w[first_name last_name primary_email confirm_email].each do |key|
        field = form.form_fields.find_by(field_key: key)
        expect(field).to be_present, "expected field_key '#{key}' to exist"
        expect(field.field_group).to eq("contact")
      end
    end

    it "inherits consent fields from BaseRegistrationFormBuilder" do
      field = form.form_fields.find_by(field_key: "communication_consent")
      expect(field).to be_present
      expect(field.answer_type).to eq("multiple_choice_radio")
      expect(field.is_required).to be true
      expect(field.field_group).to eq("consent")
    end

    it "inherits scholarship fields from BaseRegistrationFormBuilder" do
      field = form.form_fields.find_by(field_key: "scholarship_eligibility")
      expect(field).to be_present
      expect(field.field_group).to eq("scholarship")
    end

    it "creates short-specific qualitative fields" do
      referral = form.form_fields.find_by(field_key: "referral_source")
      expect(referral.answer_type).to eq("multiple_choice_checkbox")
      expect(referral.is_required).to be true

      interest = form.form_fields.find_by(field_key: "training_interest")
      expect(interest.answer_type).to eq("multiple_choice_checkbox")
      expect(interest.is_required).to be true
    end
  end

  describe ".build_standalone!" do
    it "creates a form without linking to an event" do
      form = described_class.build_standalone!

      expect(form.name).to eq("Short Event Registration")
      expect(form.event_forms).to be_empty
    end
  end
end
