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

  it "links a workshop instead of a resource" do
    link = build(:form_field_resource, resource: nil, workshop: create(:workshop, title: "Touchstone Journey"))

    expect(link).to be_valid
    expect(link.topic.title).to eq("Touchstone Journey")
  end

  it "requires exactly one of a workshop or a resource" do
    expect(build(:form_field_resource, resource: nil)).not_to be_valid
    expect(build(:form_field_resource, workshop: create(:workshop))).not_to be_valid
  end

  describe "#topic_sgid=" do
    it "links whichever kind the signed id resolves to" do
      workshop = create(:workshop)
      link = build(:form_field_resource, resource: create(:resource))

      link.topic_sgid = workshop.to_sgid.to_s

      expect(link).to have_attributes(workshop: workshop, resource: nil)
      expect(link).to be_valid
    end

    it "links nothing for a signed id of any other model" do
      link = build(:form_field_resource, resource: nil)

      link.topic_sgid = create(:person).to_sgid.to_s

      expect(link.topic).to be_nil
      expect(link).not_to be_valid
    end
  end

  it "requires a unique workshop per form field" do
    existing = create(:form_field_resource, resource: nil, workshop: create(:workshop))
    dup = build(:form_field_resource, form_field: existing.form_field, resource: nil, workshop: existing.workshop)
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
