require "rails_helper"

RSpec.describe ResourcePolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, super_user: true }
  let(:regular_user) { build_stubbed :user, super_user: false }
  let(:published_resource) { build_stubbed :resource, inactive: false, kind: "Handout" }
  let(:unpublished_resource) { build_stubbed :resource, inactive: true, kind: "Handout" }

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

      it { is_expected.to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "when resource is published" do
      context "with admin user" do
        subject { policy_for(record: published_resource, user: admin_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with regular user" do
        subject { policy_for(record: published_resource, user: regular_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end
    end

    context "when resource is unpublished" do
      context "with admin user" do
        subject { policy_for(record: unpublished_resource, user: admin_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with regular user" do
        subject { policy_for(record: unpublished_resource, user: regular_user) }

        it { is_expected.not_to be_allowed_to(:show?) }
      end
    end
  end

  describe "#manage?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:manage?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:manage?) }
    end
  end

  describe "aliases to :manage?" do
    let(:policy) { policy_for(user: admin_user) }

    describe "#new?" do
      it "is an alias of :manage? authorization rule" do
        expect(:new?).to be_an_alias_of(policy, :manage?)
      end
    end

    describe "#create?" do
      it "is an alias of :manage? authorization rule" do
        expect(:create?).to be_an_alias_of(policy, :manage?)
      end
    end

    describe "#edit?" do
      it "is an alias of :manage? authorization rule" do
        expect(:edit?).to be_an_alias_of(policy, :manage?)
      end
    end

    describe "#update?" do
      it "is an alias of :manage? authorization rule" do
        expect(:update?).to be_an_alias_of(policy, :manage?)
      end
    end

    describe "#destroy?" do
      it "is an alias of :manage? authorization rule" do
        expect(:destroy?).to be_an_alias_of(policy, :manage?)
      end
    end
  end

  describe "#download?" do
    context "with admin user" do
      subject { policy_for(record: published_resource, user: admin_user) }

      it { is_expected.to be_allowed_to(:download?) }
    end

    context "with regular user" do
      subject { policy_for(record: published_resource, user: regular_user) }

      it { is_expected.to be_allowed_to(:download?) }
    end
  end

  describe "#filter_published?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:filter_published?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:filter_published?) }
    end
  end

  describe "relation_scope" do
    context "with admin user" do
      let(:policy) { policy_for(record: Resource, user: admin_user) }

      it "returns all resources" do
        scope = policy.apply_scope(Resource.all, type: :active_record_relation)
        expect(scope).to eq(Resource.all)
      end
    end

    context "with regular user" do
      let(:policy) { policy_for(record: Resource, user: regular_user) }

      it "returns only published resources" do
        scope = policy.apply_scope(Resource.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`resources`.`inactive` = FALSE')
      end
    end
  end
end
