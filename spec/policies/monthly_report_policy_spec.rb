# frozen_string_literal: true

require "rails_helper"

RSpec.describe MonthlyReportPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }
  let(:project) { create(:project) }
  let(:project_member) { create(:user, super_user: false) }
  let(:monthly_report) { create(:report, :monthly, project: project) }

  before do
    create(:project_user, user: project_member, project: project)
  end

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Report, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "allows admin users" do
      policy = described_class.new(monthly_report, user: admin_user)
      expect(policy.show?).to be true
    end

    it "allows project members" do
      policy = described_class.new(monthly_report, user: project_member)
      expect(policy.show?).to be true
    end

    it "denies users who are not project members" do
      policy = described_class.new(monthly_report, user: regular_user)
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(Report.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(monthly_report, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(monthly_report, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end
end
