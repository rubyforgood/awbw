require "rails_helper"

RSpec.describe StaffTaggingPolicy, type: :policy do
  let(:staff_tagging) { create(:staff_tagging) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user, super_user: false) }

  def policy_for(user:, record: staff_tagging)
    described_class.new(record, user: user)
  end

  %i[index? new? create? edit? update? destroy?].each do |rule|
    describe "##{rule}" do
      it { expect(policy_for(user: admin_user)).to be_allowed_to(rule) }
      it { expect(policy_for(user: regular_user)).not_to be_allowed_to(rule) }
      it { expect(policy_for(user: nil)).not_to be_allowed_to(rule) }
    end
  end

  describe "relation scope" do
    it "shows all staff taggings to admins" do
      staff_tagging
      scope = policy_for(user: admin_user).apply_scope(StaffTagging.all, type: :active_record_relation)
      expect(scope).to include(staff_tagging)
    end

    it "hides all staff taggings from non-admins" do
      staff_tagging
      scope = policy_for(user: regular_user).apply_scope(StaffTagging.all, type: :active_record_relation)
      expect(scope).to be_empty
    end
  end
end
