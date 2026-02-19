require "rails_helper"

RSpec.describe OrganizationPolicy, type: :policy do
  let(:admin_user) { build_stubbed(:user, :admin) }
  let(:regular_user) { build_stubbed(:user) }

  let(:organization) { build_stubbed(:organization) }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#index?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:index?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(record: organization, user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with regular user" do
      subject { policy_for(record: organization, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user" do
      subject { policy_for(record: organization, user: nil) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#populations_served?" do
    context "with admin user" do
      subject { policy_for(record: organization, user: admin_user) }

      it { is_expected.to be_allowed_to(:populations_served?) }
    end

    context "with regular user" do
      subject { policy_for(record: organization, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:populations_served?) }
    end
  end

  describe "relation_scope" do
    context "with admin user" do
      let(:policy) { policy_for(record: Organization, user: admin_user) }

      it "returns all organizations" do
        scope = policy.apply_scope(Organization.all, type: :active_record_relation)
        expect(scope).to eq(Organization.all)
      end
    end

    context "with regular user" do
      let(:policy) { policy_for(record: Organization, user: regular_user) }

      it "filters to published organizations" do
        scope = policy.apply_scope(Organization.all, type: :active_record_relation)
        expect(scope.to_sql).to eq(Organization.published.to_sql)
      end
    end
  end
end
