require "rails_helper"

RSpec.describe ScholarshipApplicationFormBuilder do
  let(:event) { create(:event) }

  describe ".build!" do
    subject(:form) { described_class.build!(event) }

    it "creates a standalone scholarship form linked to the event" do
      expect(form.name).to eq("Scholarship Application")
      expect(form.scholarship_application).to be true
      expect(event.scholarship_form).to eq(form)
    end

    it "creates all expected form fields" do
      expect(form.form_fields.count).to eq(5)
    end

    it "assigns sequential positions starting at 1" do
      positions = form.form_fields.unscoped.where(form: form).order(:position).pluck(:position)
      expect(positions).to eq((1..5).to_a)
    end

    it "creates a Scholarship Application header" do
      headers = form.form_fields.where(answer_type: :group_header).pluck(:question)
      expect(headers).to contain_exactly("Scholarship Application")
    end

    it "creates scholarship eligibility as a required checkbox" do
      field = form.form_fields.find_by(field_key: "scholarship_eligibility")

      expect(field.answer_type).to eq("multiple_choice_checkbox")
      expect(field.is_required).to be true
      expect(field.form_field_answer_options.count).to eq(1)
    end

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

    it "assigns all fields to the scholarship group" do
      groups = form.form_fields.pluck(:field_group).uniq
      expect(groups).to eq([ "scholarship" ])
    end
  end

  describe ".build_standalone!" do
    it "creates a form without linking to an event" do
      form = described_class.build_standalone!

      expect(form.name).to eq("Scholarship Application")
      expect(form.scholarship_application).to be true
      expect(form.event_forms).to be_empty
    end
  end
end
