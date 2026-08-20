require "rails_helper"

RSpec.describe AffiliationPolicy, type: :policy do
  let(:admin_user) { build_stubbed(:user, :admin) }
  let(:regular_user) { build_stubbed(:user) }

  let(:affiliation) { build_stubbed(:affiliation) }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  %i[ edit? update? destroy? ].each do |rule|
    describe "##{rule}" do
      context "with admin user" do
        subject { policy_for(record: affiliation, user: admin_user) }

        it { is_expected.to be_allowed_to(rule) }
      end

      context "with regular user" do
        subject { policy_for(record: affiliation, user: regular_user) }

        it { is_expected.not_to be_allowed_to(rule) }
      end

      context "with no user" do
        subject { policy_for(record: affiliation, user: nil) }

        it { is_expected.not_to be_allowed_to(rule) }
      end
    end
  end
end
