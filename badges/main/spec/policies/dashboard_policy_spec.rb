require "rails_helper"

RSpec.describe DashboardPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, super_user: true }
  let(:regular_user) { build_stubbed :user, super_user: false }

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

    context "without user" do
      subject { policy_for(user: nil) }

      it { is_expected.to be_allowed_to(:index?) }
    end
  end

  describe "relation_scope" do
    context "with authenticated user (admin)" do
      let(:policy) { policy_for(record: Workshop, user: admin_user) }

      it "returns featured scope for authenticated users" do
        scope = policy.apply_scope(Workshop.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`workshops`.`featured` = TRUE')
      end
    end

    context "with authenticated user (regular)" do
      let(:policy) { policy_for(record: Workshop, user: regular_user) }

      it "returns featured scope for authenticated users" do
        scope = policy.apply_scope(Workshop.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`workshops`.`featured` = TRUE')
      end
    end

    context "without user" do
      let(:policy) { policy_for(record: Workshop, user: nil) }

      it "returns visitor_featured scope for unauthenticated users" do
        scope = policy.apply_scope(Workshop.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`workshops`.`visitor_featured` = TRUE')
      end
    end
  end
end
