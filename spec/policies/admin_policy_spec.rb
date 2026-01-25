# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#admin?" do
    it "returns true for super_user" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.admin?).to be true
    end

    it "returns false for regular user" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.admin?).to be false
    end
  end

  describe "#index?" do
    it "allows admin users" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.index?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.index?).to be false
    end
  end

  describe "#show?" do
    it "allows admin users" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.show?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "allows admin users" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.create?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.create?).to be false
    end
  end

  describe "#update?" do
    it "allows admin users" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.update?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(:admin, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:admin, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end
end
