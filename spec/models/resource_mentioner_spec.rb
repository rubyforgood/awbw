require 'rails_helper'

RSpec.describe Resource, type: :model do
  it_behaves_like "mentioner"

  describe "resource-specific mentions" do
    let(:resource) { create(:resource) }
    let(:workshop) { create(:workshop, title: "Related Workshop") }
    let(:other_resource) { create(:resource, title: "Other Resource") }

    it "can mention both workshops and resources" do
      # Add mention to resource's body field with content
      rich_text = resource.rhino_body
      rich_text.update!(body: "<p>See @workshop[#{workshop.id}] and @resource[#{other_resource.id}]</p>")

      ActionTextMention.create!(
        action_text_rich_text_id: rich_text.id,
        mentionable_type: "Workshop",
        mentionable_id: workshop.id
      )

      ActionTextMention.create!(
        action_text_rich_text_id: rich_text.id,
        mentionable_type: "Resource",
        mentionable_id: other_resource.id
      )

      mentions = resource.all_mentions_grouped
      expect(mentions).to have_key("Workshop")
      expect(mentions).to have_key("Resource")
      expect(mentions["Workshop"]).to include(workshop)
      expect(mentions["Resource"]).to include(other_resource)
    end

    it "handles single field model correctly" do
      # Resource only has one rich text field
      fields = Resource.mentionable_rich_text_fields
      expect(fields).to eq([ :rhino_body ])
    end

    it "handles mentions in single field" do
      # Resource only has rhino_body field
      rich_text = resource.rhino_body
      rich_text.update!(body: "<p>Single field test with @workshop[#{workshop.id}]</p>")

      ActionTextMention.create!(
        action_text_rich_text_id: rich_text.id,
        mentionable_type: "Workshop",
        mentionable_id: workshop.id
      )

      mentions = resource.all_mentions_grouped
      expect(mentions).to have_key("Workshop")
      expect(mentions["Workshop"]).to include(workshop)
    end
  end
end
