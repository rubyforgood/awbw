require "rails_helper"

RSpec.describe ActionTextMention do
  describe "syncing from rich text" do
    let(:workshop) { create(:workshop) }
    let(:resource) { create(:resource) }
    let(:mention_html) { "<p>Use #{ActionText::Attachment.from_attachable(resource).to_html}</p>" }

    it "records a mention added to a rich text field saved for the first time" do
      workshop.update!(rhino_materials: mention_html)

      expect(ActionTextMention.where(mentionable: resource).map { |mention| mention.action_text_rich_text.record })
        .to eq([ workshop ])
    end

    it "records a mention added to an existing rich text field" do
      workshop.update!(rhino_materials: "<p>Paper</p>")
      workshop.update!(rhino_materials: mention_html)

      expect(ActionTextMention.where(mentionable: resource).count).to eq(1)
    end

    it "removes the mention when it leaves the text" do
      workshop.update!(rhino_materials: mention_html)
      workshop.update!(rhino_materials: "<p>Paper</p>")

      expect(ActionTextMention.where(mentionable: resource)).to be_empty
    end
  end
end
