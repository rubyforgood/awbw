require "rails_helper"

RSpec.describe ExtendedEventRegistrationFormBuilder do
  let(:event) { create(:event) }

  describe ".build!" do
    subject(:form) { described_class.build!(event) }

    it "creates a registration form linked to the event" do
      expect(form.name).to eq("Extended Event Registration")
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

    it "adds extended contact fields beyond the basic set" do
      extended_keys = %w[nickname pronouns primary_email_type secondary_email secondary_email_type
                         mailing_street mailing_address_type mailing_city mailing_state mailing_zip
                         phone phone_type agency_name agency_position]
      extended_keys.each do |key|
        field = form.form_fields.find_by(field_key: key)
        expect(field).to be_present, "expected field_key '#{key}' to exist"
      end
    end

    it "creates workshop_environments field with correct key" do
      field = form.form_fields.find_by(field_key: "workshop_environments")
      expect(field).to be_present
      expect(field.answer_type).to eq("multiple_choice_checkbox")
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

    it "creates payment fields" do
      attendees = form.form_fields.find_by(field_key: "number_of_attendees")
      expect(attendees.answer_datatype).to eq("number_integer")
      expect(attendees.is_required).to be true

      payment = form.form_fields.find_by(field_key: "payment_method")
      expect(payment.answer_type).to eq("multiple_choice_radio")
    end

    it "creates all expected field groups" do
      groups = form.form_fields.pluck(:field_group).uniq.sort
      expect(groups).to contain_exactly("background", "consent", "contact", "payment", "professional", "qualitative", "scholarship")
    end
  end

  describe ".build! without contact fields" do
    subject(:form) { described_class.build!(event, include_contact_fields: false) }

    it "omits contact fields" do
      expect(form.form_fields.find_by(field_key: "first_name")).to be_nil
      expect(form.form_fields.find_by(field_key: "primary_email")).to be_nil
    end

    it "still includes consent fields" do
      expect(form.form_fields.find_by(field_key: "communication_consent")).to be_present
    end

    it "still includes scholarship fields" do
      expect(form.form_fields.find_by(field_key: "scholarship_eligibility")).to be_present
    end
  end

  describe ".build_standalone!" do
    it "creates a form without linking to an event" do
      form = described_class.build_standalone!

      expect(form.name).to eq("Extended Event Registration")
      expect(form.event_forms).to be_empty
    end
  end

  describe ".copy!" do
    it "duplicates a form for a new event" do
      source_form = described_class.build!(event)
      new_event = create(:event)

      copied = described_class.copy!(from_form: source_form, to_event: new_event)

      expect(copied.id).not_to eq(source_form.id)
      expect(copied.form_fields.count).to eq(source_form.form_fields.count)
      expect(new_event.registration_form).to eq(copied)
    end
  end
end
