require 'rails_helper'

RSpec.describe Workshop, type: :model do
  it_behaves_like "mentioner"

  describe "mentionable_rich_text_fields" do
    it "has many rich text fields for comprehensive testing" do
      fields = Workshop.mentionable_rich_text_fields
      expect(fields.count).to be >= 30
    end

    it "includes both English and Spanish fields" do
      fields = Workshop.mentionable_rich_text_fields
      expect(fields).to include(:rhino_objective)
      expect(fields).to include(:rhino_objective_spanish)
      expect(fields).to include(:rhino_materials)
      expect(fields).to include(:rhino_materials_spanish)
    end
  end

  describe "workshop-specific mentions" do
    let(:workshop) { create(:workshop) }
    let(:resource) { create(:resource, title: "Related Resource") }
    let(:other_workshop) { create(:workshop, title: "Other Workshop") }

    it "can mention both workshops and resources" do
      rich_text = workshop.rhino_objective
      rich_text.update!(body: "<p>See @workshop[#{other_workshop.id}] and @resource[#{resource.id}]</p>")

      ActionTextMention.create!(
        action_text_rich_text_id: rich_text.id,
        mentionable_type: "Workshop",
        mentionable_id: other_workshop.id
      )

      ActionTextMention.create!(
        action_text_rich_text_id: rich_text.id,
        mentionable_type: "Resource",
        mentionable_id: resource.id
      )

      mentions = workshop.all_mentions_grouped
      expect(mentions).to have_key("Workshop")
      expect(mentions).to have_key("Resource")
      expect(mentions["Workshop"]).to include(other_workshop)
      expect(mentions["Resource"]).to include(resource)
    end

    it "handles multi-field deduplication correctly" do
      workshop = create(:workshop, title: "Dedup Test")

      workshop.rhino_objective.update!(body: "<p>@workshop[#{other_workshop.id}] in objective</p>")
      workshop.rhino_materials.update!(body: "<p>@workshop[#{other_workshop.id}] in materials</p>")

      ActionTextMention.create!(
        action_text_rich_text_id: workshop.rhino_objective.id,
        mentionable_type: "Workshop",
        mentionable_id: other_workshop.id
      )

      ActionTextMention.create!(
        action_text_rich_text_id: workshop.rhino_materials.id,
        mentionable_type: "Workshop",
        mentionable_id: other_workshop.id
      )

      mentions = workshop.all_mentions_grouped
      expect(mentions["Workshop"]).to include(other_workshop)
      expect(mentions["Workshop"].count).to eq(1) # deduplicated
    end
  end
end
