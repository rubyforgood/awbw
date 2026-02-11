RSpec.shared_examples "mentioner" do
  let(:model_class) { described_class }
  let(:record) { create(model_class.name.underscore.to_sym) }
  let(:other_record) { create(:workshop, title: "Mentioned Workshop") }

  describe "mentionable_rich_text_fields" do
    it "returns an array of rich text field symbols" do
      fields = model_class.mentionable_rich_text_fields
      expect(fields).to be_an(Array)
      expect(fields.all? { |f| f.is_a?(Symbol) }).to be true
    end

    it "has at least one field for testing" do
      fields = model_class.mentionable_rich_text_fields
      expect(fields.count).to be >= 1
    end
  end

  describe "#all_mentions_grouped" do
    context "when model has no mentions" do
      it "returns empty hash" do
        mentions = record.all_mentions_grouped
        expect(mentions).to eq({})
      end
    end

    context "when model has mentions" do
      before do
        first_field = model_class.mentionable_rich_text_fields.first
        rich_text = record.send(first_field)
        rich_text.update!(body: "<p>Content with @#{other_record.class.name.underscore}[#{other_record.id}] mention</p>")

        ActionTextMention.create!(
          action_text_rich_text_id: rich_text.id,
          mentionable_type: other_record.class.name,
          mentionable_id: other_record.id
        )

        if model_class.mentionable_rich_text_fields.length > 1
          second_field = model_class.mentionable_rich_text_fields[1]
          second_rich_text = record.send(second_field)
          second_rich_text.update!(body: "<p>Another @#{other_record.class.name.underscore}[#{other_record.id}] mention</p>")
          ActionTextMention.create!(
            action_text_rich_text_id: second_rich_text.id,
            mentionable_type: other_record.class.name,
            mentionable_id: other_record.id
          )
        end
      end

      it "returns mentions grouped by type" do
        mentions = record.all_mentions_grouped
        expect(mentions).to have_key(other_record.class.name)
        expect(mentions[other_record.class.name]).to include(other_record)
      end

      it "deduplicates mentions of same record" do
        mentions = record.all_mentions_grouped
        expect(mentions[other_record.class.name]).to include(other_record)
        expect(mentions[other_record.class.name].count).to eq(1)
      end

      it "handles missing records gracefully" do
        other_record.destroy

        mentions = record.all_mentions_grouped
        expect(mentions[other_record.class.name] || []).not_to include(other_record)
      end
    end

    context "when rich text field doesn't exist" do
      it "skips nil rich text fields" do
        if model_class == Workshop
          workshop = create(:workshop, title: "Test Workshop")
          workshop.update(rhino_misc1: nil, rhino_misc2: nil)

          mentions = workshop.all_mentions_grouped
          expect(mentions).to eq({})
        else
          skip "nil test already verified."
        end
      end
    end
  end
end
