require "rails_helper"

RSpec.describe FeaturePolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }

  let(:published_user_facing) { build_stubbed :feature, published: true, display_status: "user_facing" }
  let(:published_admin_facing) { build_stubbed :feature, published: true, display_status: "admin_facing" }
  let(:unpublished) { build_stubbed :feature, published: false, display_status: "user_facing" }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#index?" do
    it { expect(policy_for(user: admin_user)).to be_allowed_to(:index?) }
    it { expect(policy_for(user: regular_user)).to be_allowed_to(:index?) }
    it { expect(policy_for(user: nil)).not_to be_allowed_to(:index?) }
  end

  describe "#show?" do
    it "lets a regular user see a published, non-admin-facing feature" do
      expect(policy_for(record: published_user_facing, user: regular_user)).to be_allowed_to(:show?)
    end

    it "hides an admin-facing feature from a regular user" do
      expect(policy_for(record: published_admin_facing, user: regular_user)).not_to be_allowed_to(:show?)
    end

    it "hides an unpublished feature from a regular user" do
      expect(policy_for(record: unpublished, user: regular_user)).not_to be_allowed_to(:show?)
    end

    it "lets an admin see anything" do
      expect(policy_for(record: published_admin_facing, user: admin_user)).to be_allowed_to(:show?)
      expect(policy_for(record: unpublished, user: admin_user)).to be_allowed_to(:show?)
    end

    it "denies a logged-out visitor" do
      expect(policy_for(record: published_user_facing, user: nil)).not_to be_allowed_to(:show?)
    end
  end

  describe "manage rules (create/update/destroy)" do
    %i[create? update? destroy?].each do |rule|
      it "allows only admins for #{rule}" do
        record = build_stubbed(:feature)
        expect(policy_for(record: record, user: admin_user)).to be_allowed_to(rule)
        expect(policy_for(record: record, user: regular_user)).not_to be_allowed_to(rule)
      end
    end
  end

  describe "relation scope" do
    let!(:published_user_facing) { create(:feature, published: true, display_status: "user_facing") }
    let!(:published_admin_facing) { create(:feature, published: true, display_status: "admin_facing") }
    let!(:draft) { create(:feature, published: false, display_status: "user_facing") }

    it "gives admins everything" do
      scope = described_class.new(nil, user: admin_user).apply_scope(Feature.all, type: :active_record_relation)
      expect(scope).to contain_exactly(published_user_facing, published_admin_facing, draft)
    end

    it "gives regular users only published, non-admin-facing features" do
      scope = described_class.new(nil, user: regular_user).apply_scope(Feature.all, type: :active_record_relation)
      expect(scope).to contain_exactly(published_user_facing)
    end

    it "gives logged-out visitors nothing" do
      scope = described_class.new(nil, user: nil).apply_scope(Feature.all, type: :active_record_relation)
      expect(scope).to be_empty
    end
  end
end
