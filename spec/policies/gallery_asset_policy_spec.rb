require "rails_helper"

RSpec.describe GalleryAssetPolicy, type: :policy do
  let(:admin_user)   { build_stubbed(:user, super_user: true) }
  let(:regular_user) { build_stubbed(:user, super_user: false) }
  let(:guest_user)   { nil }

  def policy_for(record:, user:)
    described_class.new(record, user: user)
  end

  describe "#index?" do
    it "allows admin" do
      expect(policy_for(record: GalleryAsset, user: admin_user)).to be_allowed_to(:index?)
    end

    it "denies regular user" do
      expect(policy_for(record: GalleryAsset, user: regular_user)).not_to be_allowed_to(:index?)
    end

    it "denies guest" do
      expect(policy_for(record: GalleryAsset, user: guest_user)).not_to be_allowed_to(:index?)
    end
  end

  describe "#update?" do
    let(:gallery_asset) { build_stubbed(:gallery_asset) }

    it "allows admin" do
      expect(policy_for(record: gallery_asset, user: admin_user)).to be_allowed_to(:update?)
    end

    it "denies regular user" do
      expect(policy_for(record: gallery_asset, user: regular_user)).not_to be_allowed_to(:update?)
    end
  end
end
