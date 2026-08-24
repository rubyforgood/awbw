require "rails_helper"

RSpec.describe StaffTagPolicy, type: :policy do
  let(:staff_tag) { create(:staff_tag) }
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user, super_user: false) }

  def policy_for(user:, record: staff_tag)
    described_class.new(record, user: user)
  end

  %i[index? show? create? update? destroy? archive? unarchive?].each do |rule|
    describe "##{rule}" do
      it { expect(policy_for(user: admin_user)).to be_allowed_to(rule) }
      it { expect(policy_for(user: regular_user)).not_to be_allowed_to(rule) }
      it { expect(policy_for(user: nil)).not_to be_allowed_to(rule) }
    end
  end

  describe "relation scope" do
    it "shows all staff tags to admins" do
      staff_tag
      scope = policy_for(user: admin_user).apply_scope(StaffTag.all, type: :active_record_relation)
      expect(scope).to include(staff_tag)
    end

    it "hides all staff tags from non-admins" do
      staff_tag
      scope = policy_for(user: regular_user).apply_scope(StaffTag.all, type: :active_record_relation)
      expect(scope).to be_empty
    end
  end
end
