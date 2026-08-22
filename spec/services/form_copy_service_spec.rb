require "rails_helper"

RSpec.describe FormCopyService do
  describe "#call" do
    it "names the copy \"COPY of [name]\"" do
      form = create(:form, name: "Volunteer Intake")

      copy = described_class.new(form).call

      expect(copy.name).to eq("COPY of Volunteer Intake")
    end

    it "clears the agreement purpose so two forms never share a scenario" do
      form = create(:form, purpose: "reinstatement_agreement")

      copy = described_class.new(form).call

      expect(copy.purpose).to be_nil
    end

    it "returns a persisted, distinct record" do
      form = create(:form)

      copy = described_class.new(form).call

      expect(copy).to be_persisted
      expect(copy.id).not_to eq(form.id)
    end

    it "copies every form field with its attributes and order" do
      form = create(:form)
      create(:form_field, form: form, name: "First name", position: 1, required: true, section: "person")
      create(:form_field, form: form, name: "Notes", position: 2, required: false, section: "extra")

      copy = described_class.new(form).call

      fields = copy.form_fields.order(:position)
      expect(fields.map(&:name)).to eq([ "First name", "Notes" ])
      expect(fields.map(&:section)).to eq([ "person", "extra" ])
      expect(fields.map(&:required)).to eq([ true, false ])
    end

    it "copies answer options by re-pointing at the shared AnswerOption records" do
      form = create(:form)
      field = create(:form_field, form: form)
      option = create(:answer_option, name: "Yes")
      create(:form_field_answer_option, form_field: field, answer_option: option)

      copy = nil
      expect { copy = described_class.new(form).call }.not_to change(AnswerOption, :count)

      copied_option = copy.form_fields.first.form_field_answer_options.first
      expect(copied_option.answer_option).to eq(option)
    end

    it "does not copy the slug or published state" do
      form = create(:form, slug: "volunteer", published: true, name: "Volunteer")

      copy = described_class.new(form).call

      expect(copy.slug).to be_nil
      expect(copy.published).to be(false)
    end

    it "does not copy submissions or event links" do
      form = create(:form)
      EventForm.create!(form: form, event: create(:event), role: "registration")

      copy = described_class.new(form).call

      expect(copy.event_forms).to be_empty
      expect(copy.form_submissions).to be_empty
    end

    it "leaves the original form untouched" do
      form = create(:form, name: "Original")
      create(:form_field, form: form)

      expect { described_class.new(form).call }.to change(Form, :count).by(1)
      expect(form.reload.name).to eq("Original")
      expect(form.form_fields.count).to eq(1)
    end
  end
end
