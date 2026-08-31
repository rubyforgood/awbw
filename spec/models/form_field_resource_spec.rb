require "rails_helper"

RSpec.describe FormFieldResource, type: :model do
  it "is valid with a form field and resource" do
    expect(build(:form_field_resource)).to be_valid
  end

  it "requires a unique resource per form field" do
    existing = create(:form_field_resource)
    dup = build(:form_field_resource, form_field: existing.form_field, resource: existing.resource)
    expect(dup).not_to be_valid
  end

  it "orders by position" do
    field = create(:form_field)
    later = create(:form_field_resource, form_field: field, position: 2)
    earlier = create(:form_field_resource, form_field: field, position: 1)
    expect(field.form_field_resources.reload.to_a).to eq([ earlier, later ])
  end

  describe "FormField#per_resource?" do
    it "is true only once resources are linked to a choice field" do
      field = create(:form_field, answer_type: :single_select_radio)
      expect(field.per_resource?).to be(false)
      create(:form_field_resource, form_field: field)
      expect(field.reload.per_resource?).to be(true)
    end

    # Each copy renders the field's answer options, so a field switched away from a
    # choice type falls back to an ordinary question rather than rendering nothing.
    it "is false for a linked field that is no longer a choice field" do
      field = create(:form_field, answer_type: :single_select_radio)
      create(:form_field_resource, form_field: field)

      field.update!(answer_type: :free_form_input_paragraph)

      expect(field.reload.per_resource?).to be(false)
    end

    it "exposes the linked resources through the join" do
      field = create(:form_field)
      link = create(:form_field_resource, form_field: field)
      expect(field.resources).to include(link.resource)
    end
  end
end
