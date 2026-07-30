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

      it "includes organizations with an active affiliation and excludes those without one" do
        regular = create(:user)
        with_active_affiliation = create(:organization)
        create(:affiliation, organization: with_active_affiliation, inactive: false, end_date: nil)

        # An expired affiliation isn't active, and the factory status is never
        # "Active", so this org matches neither branch of `published`/`active`.
        without_active_affiliation = create(:organization)
        create(:affiliation, organization: without_active_affiliation, end_date: 1.day.ago)

        # The scope is broader than "has an active affiliation": an org flagged
        # "Active" by status alone still qualifies, even with no affiliations.
        active_by_status = create(:organization, organization_status: create(:organization_status, name: "Active"))

        policy = described_class.new(Organization, user: regular)
        scope = policy.apply_scope(Organization.all, type: :active_record_relation)

        expect(scope).to include(with_active_affiliation, active_by_status)
        expect(scope).not_to include(without_active_affiliation)
      end
    end
  end
end
