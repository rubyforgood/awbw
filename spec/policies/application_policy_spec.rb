require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:record) { build_stubbed(:organization) }

  def policy_for(user)
    described_class.new(record, user: user)
  end

  describe "#super_admin?" do
    it "is true for a super user" do
      expect(policy_for(build_stubbed(:user, :admin)).send(:super_admin?)).to be(true)
    end

    it "is true for a global super_admin role" do
      user = build_stubbed(:user)
      allow(user).to receive(:has_role?).with(:super_admin).and_return(true)

      expect(policy_for(user).send(:super_admin?)).to be(true)
    end

    it "is false otherwise" do
      user = build_stubbed(:user)
      allow(user).to receive(:has_role?).with(:super_admin).and_return(false)

      expect(policy_for(user).send(:super_admin?)).to be(false)
    end
  end

  describe "#member?" do
    it "is true for a global member role" do
      user = build_stubbed(:user)
      allow(user).to receive(:has_role?).with(:member).and_return(true)

      expect(policy_for(user).send(:member?)).to be(true)
    end

    it "is true for a paid member" do
      user = build_stubbed(:user)
      allow(user).to receive(:has_role?).with(:member).and_return(false)
      allow(user).to receive(:paid_member?).and_return(true)

      expect(policy_for(user).send(:member?)).to be(true)
    end

    it "is false for a non-member" do
      user = build_stubbed(:user)
      allow(user).to receive(:has_role?).with(:member).and_return(false)
      allow(user).to receive(:paid_member?).and_return(false)

      expect(policy_for(user).send(:member?)).to be(false)
    end
  end
end
