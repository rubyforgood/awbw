require "rails_helper"

RSpec.describe GrantPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:grant) { build_stubbed :grant }

  def policy_for(record: grant, user:)
    described_class.new(record, user: user)
  end

  %i[index? show? new? create? edit? update? destroy?].each do |rule|
    describe "##{rule}" do
      context "with admin user" do
        subject { policy_for(user: admin_user) }

        it { is_expected.to be_allowed_to(rule) }
      end

      context "with regular user" do
        subject { policy_for(user: regular_user) }

        it { is_expected.not_to be_allowed_to(rule) }
      end
    end
  end

  describe "relation_scope" do
    let!(:existing_grant) { create(:grant) }

    it "returns all grants for admins" do
      policy = policy_for(user: create(:user, :admin))
      scope = policy.apply_scope(Grant.all, type: :active_record_relation)
      expect(scope).to contain_exactly(existing_grant)
    end

    it "returns no grants for regular users" do
      policy = policy_for(user: create(:user))
      scope = policy.apply_scope(Grant.all, type: :active_record_relation)
      expect(scope).to be_empty
    end
  end
end
