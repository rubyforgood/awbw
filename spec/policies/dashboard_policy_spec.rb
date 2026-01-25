# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(:dashboard, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#admin_dashboard?" do
    it "allows admin users" do
      policy = described_class.new(:dashboard, user: admin_user)
      expect(policy.admin_dashboard?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:dashboard, user: regular_user)
      expect(policy.admin_dashboard?).to be false
    end
  end

  describe "#view_other_user_activities?" do
    it "allows admin users" do
      policy = described_class.new(:dashboard, user: admin_user)
      expect(policy.view_other_user_activities?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(:dashboard, user: regular_user)
      expect(policy.view_other_user_activities?).to be false
    end
  end
end
