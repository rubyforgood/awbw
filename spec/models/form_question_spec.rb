require "rails_helper"

RSpec.describe FormQuestion do
  let(:form) { create(:form, :standalone) }
  let(:field) { create(:form_field, form: form, name: "How clear was", answer_type: :single_select_radio) }
  let(:masks) { create(:resource, title: "Masks") }

  describe ".for_field" do
    it "is the field alone when it isn't fanned out" do
      questions = described_class.for_field(field)

      expect(questions.map(&:label)).to eq([ "How clear was" ])
      expect(questions.map(&:resource)).to eq([ nil ])
    end

    it "is one copy per linked resource when fanned out" do
      collage = create(:resource, title: "Collage")
      create(:form_field_resource, form_field: field, resource: collage, position: 1)
      create(:form_field_resource, form_field: field, resource: masks, position: 2)

      expect(described_class.for_field(field.reload).map(&:label)).to eq([ "How clear was Collage", "How clear was Masks" ])
    end
  end

  describe ".find" do
    it "is nil for a stale field or resource id" do
      expect(described_class.find(0)).to be_nil
      expect(described_class.find(field.id, 0)).to be_nil
    end
  end

  describe "#answers" do
    it "matches a copy's answers by sentence within the field's form" do
      mine = create(:form_answer, form_field: nil, question_name_when_answered: "How clear was Masks",
                    form_submission: create(:form_submission, form: form))
      create(:form_answer, form_field: nil, question_name_when_answered: "How clear was Masks",
             form_submission: create(:form_submission, form: create(:form, :standalone)))

      expect(described_class.new(field, masks).answers).to contain_exactly(mine)
    end

    it "is the field's own answers for a plain question" do
      own = create(:form_answer, form_field: field, form_submission: create(:form_submission, form: form))

      expect(described_class.new(field).answers).to contain_exactly(own)
    end
  end
end
