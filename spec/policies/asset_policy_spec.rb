require "rails_helper"

RSpec.describe AssetPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:asset) { build_stubbed :primary_asset }

  def policy_for(record: asset, user:)
    described_class.new(record, user: user)
  end

  %i[index? new? create? update?].each do |rule|
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
end
