# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkshopLogPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }
  let(:owner_user) { create(:user, super_user: false) }
  let(:project) { create(:project) }
  let(:project_member) { create(:user, super_user: false) }
  let(:workshop_log) { create(:workshop_log, created_by: owner_user, project: project) }

  before do
    create(:project_user, user: project_member, project: project)
  end

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(WorkshopLog, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "allows admin users" do
      policy = described_class.new(workshop_log, user: admin_user)
      expect(policy.show?).to be true
    end

    it "allows workshop log owners" do
      policy = described_class.new(workshop_log, user: owner_user)
      expect(policy.show?).to be true
    end

    it "allows project members" do
      policy = described_class.new(workshop_log, user: project_member)
      expect(policy.show?).to be true
    end

    it "denies users who are not owners or project members" do
      policy = described_class.new(workshop_log, user: regular_user)
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(WorkshopLog.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(workshop_log, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(workshop_log, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:own_log) { create(:workshop_log, created_by: regular_user) }
    let!(:project_log) { create(:workshop_log, project: project) }
    let!(:other_log) { create(:workshop_log) }

    it "returns all logs for admin users" do
      policy = described_class.new(WorkshopLog, user: admin_user)
      scope = policy.apply_scope(WorkshopLog, type: :relation)
      expect(scope).to include(own_log, project_log, other_log)
    end

    it "returns own logs and project logs for regular users" do
      policy = described_class.new(WorkshopLog, user: project_member)
      scope = policy.apply_scope(WorkshopLog, type: :relation)
      expect(scope).to include(project_log)
      expect(scope).not_to include(other_log)
    end
  end
end
