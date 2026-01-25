# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }
  let(:other_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows admin users" do
      policy = described_class.new(User, user: admin_user)
      expect(policy.index?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(User, user: regular_user)
      expect(policy.index?).to be false
    end
  end

  describe "#show?" do
    it "allows any authenticated user" do
      policy = described_class.new(other_user, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#update?" do
    it "allows admin users to update any user" do
      policy = described_class.new(other_user, user: admin_user)
      expect(policy.update?).to be true
    end

    it "allows users to update themselves" do
      policy = described_class.new(regular_user, user: regular_user)
      expect(policy.update?).to be true
    end

    it "denies regular users from updating other users" do
      policy = described_class.new(other_user, user: regular_user)
      expect(policy.update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(other_user, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(other_user, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "#toggle_lock_status?" do
    it "allows admin users" do
      policy = described_class.new(other_user, user: admin_user)
      expect(policy.toggle_lock_status?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(other_user, user: regular_user)
      expect(policy.toggle_lock_status?).to be false
    end
  end
end
