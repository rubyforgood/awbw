require "rails_helper"

RSpec.describe Feature, type: :model do
  describe "validations" do
    subject { build(:feature) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:summary) }
    it { is_expected.to validate_presence_of(:released_on) }
    it { is_expected.to validate_inclusion_of(:area).in_array(Feature::AREA_KEYS) }
    it { is_expected.to validate_inclusion_of(:display_status).in_array(Feature::DISPLAY_STATUS_KEYS) }

    it "rejects an area outside the taxonomy" do
      expect(build(:feature, area: "nonsense")).not_to be_valid
    end

    it "allows a blank external_url" do
      expect(build(:feature, external_url: "")).to be_valid
    end

    it "rejects a non-http external_url" do
      expect(build(:feature, external_url: "javascript:alert(1)")).not_to be_valid
    end

    it "accepts an https external_url" do
      expect(build(:feature, external_url: "https://docs.example.com/x")).to be_valid
    end
  end

  describe "#pro_tips_list" do
    it "splits newline-separated tips and drops blanks" do
      feature = build(:feature, pro_tips: "One\n\n  Two  \n")
      expect(feature.pro_tips_list).to eq([ "One", "Two" ])
    end

    it "is empty when there are no tips" do
      expect(build(:feature, pro_tips: nil).pro_tips_list).to eq([])
    end
  end

  describe "#admin_only?" do
    it "is true only for admin-facing features" do
      expect(build(:feature, :admin_facing)).to be_admin_only
      expect(build(:feature, :public_facing)).not_to be_admin_only
      expect(build(:feature)).not_to be_admin_only
    end
  end

  describe "scopes" do
    let!(:published)   { create(:feature, released_on: Date.new(2026, 1, 1)) }
    let!(:unpublished) { create(:feature, :unpublished, released_on: Date.new(2026, 6, 1)) }
    let!(:admin_only)  { create(:feature, :admin_facing, released_on: Date.new(2026, 3, 1)) }

    it ".published returns only published features" do
      expect(Feature.published).to contain_exactly(published, admin_only)
    end

    it ".readable_by_non_admins excludes admin-facing features" do
      expect(Feature.readable_by_non_admins).to contain_exactly(published, unpublished)
    end

    it ".by_release orders newest first" do
      expect(Feature.by_release.first).to eq(unpublished)
      expect(Feature.by_release.last).to eq(published)
    end
  end
end
