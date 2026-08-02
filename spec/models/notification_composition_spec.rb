require "rails_helper"

RSpec.describe NotificationComposition, type: :model do
  it "has a valid factory" do
    expect(build(:notification_composition)).to be_valid
  end

  describe "validations" do
    it "requires a known kind" do
      expect(build(:notification_composition, kind: "bogus")).not_to be_valid
      expect(build(:notification_composition, kind: nil)).not_to be_valid
    end

    it "requires a known scope_type" do
      expect(build(:notification_composition, scope_type: "bogus")).not_to be_valid
    end

    it "requires a name for templates but not drafts" do
      expect(build(:notification_composition, :template, name: nil)).not_to be_valid
      expect(build(:notification_composition, kind: "draft", name: nil)).to be_valid
    end
  end

  describe "scopes" do
    it "separates drafts from templates" do
      draft = create(:notification_composition, kind: "draft")
      template = create(:notification_composition, :template)

      expect(described_class.drafts).to include(draft)
      expect(described_class.drafts).not_to include(template)
      expect(described_class.templates).to include(template)
      expect(described_class.templates).not_to include(draft)
    end
  end

  describe "content block flags (presence is the flag)" do
    it "shows the CTA button only when a label is present" do
      expect(build(:notification_composition, cta_label: "Go").cta_button?).to be(true)
      expect(build(:notification_composition, cta_label: nil).cta_button?).to be(false)
    end

    it "shows the grey callout only when text is present" do
      expect(build(:notification_composition, grey_box_text: "Note").grey_box?).to be(true)
      expect(build(:notification_composition, grey_box_text: nil).grey_box?).to be(false)
    end
  end

  describe "audience recipe accessors" do
    it "coalesce nil to arrays and cast override ids to integers" do
      comp = build(:notification_composition,
                   recipient_segments: nil,
                   recipient_added_ids: [ "1", "2" ],
                   recipient_excluded_ids: nil)

      expect(comp.segments).to eq([])
      expect(comp.added_ids).to eq([ 1, 2 ])
      expect(comp.excluded_ids).to eq([])
    end
  end
end
