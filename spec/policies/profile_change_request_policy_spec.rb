require "rails_helper"

RSpec.describe ProfileChangeRequestPolicy, type: :policy do
  let(:admin) { build_stubbed(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let(:other) { build_stubbed(:user) }
  let(:request) { build_stubbed(:profile_change_request, person: person, requested_by: owner_user) }

  def policy_for(record:, user:)
    described_class.new(record, user: user)
  end

  describe "#create?" do
    it "allows the profile owner" do
      expect(policy_for(record: request, user: owner_user)).to be_allowed_to(:create?)
    end

    it "allows an admin" do
      expect(policy_for(record: request, user: admin)).to be_allowed_to(:create?)
    end

    it "denies an unrelated user" do
      expect(policy_for(record: request, user: other)).not_to be_allowed_to(:create?)
    end
  end

  describe "review actions" do
    it "allows admins to index/approve/decline/resolve" do
      policy = policy_for(record: request, user: admin)
      expect(policy).to be_allowed_to(:index?)
      expect(policy).to be_allowed_to(:approve?)
      expect(policy).to be_allowed_to(:decline?)
      expect(policy).to be_allowed_to(:resolve?)
    end

    it "denies the owner from approving" do
      expect(policy_for(record: request, user: owner_user)).not_to be_allowed_to(:approve?)
    end
  end
end
