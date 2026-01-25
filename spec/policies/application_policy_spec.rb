# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#authenticated?" do
    it "returns true when user is present" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.authenticated?).to be true
    end

    it "returns false when user is nil" do
      policy = described_class.new(Workshop.new, user: nil)
      expect(policy.authenticated?).to be false
    end
  end

  describe "#admin?" do
    it "returns true for super_user" do
      policy = described_class.new(Workshop.new, user: admin_user)
      expect(policy.admin?).to be true
    end

    it "returns false for regular user" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.admin?).to be false
    end
  end

  describe "#owner?" do
    let(:workshop) { create(:workshop, user: regular_user) }

    it "returns true when user owns the record" do
      policy = described_class.new(workshop, user: regular_user)
      expect(policy.owner?).to be true
    end

    it "returns false when user does not own the record" do
      policy = described_class.new(workshop, user: admin_user)
      expect(policy.owner?).to be false
    end
  end

  describe "#project_member?" do
    let(:project) { create(:project) }
    let(:user_with_project) { create(:user) }
    let(:workshop_log) { create(:workshop_log, project: project) }

    before do
      create(:project_user, user: user_with_project, project: project)
    end

    it "returns true when user is a project member" do
      policy = described_class.new(workshop_log, user: user_with_project)
      expect(policy.project_member?).to be true
    end

    it "returns false when user is not a project member" do
      policy = described_class.new(workshop_log, user: regular_user)
      expect(policy.project_member?).to be false
    end
  end

  describe "default CRUD rules" do
    it "allows index for authenticated users" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.index?).to be true
    end

    it "allows show for authenticated users" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.show?).to be true
    end

    it "allows create for authenticated users" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.create?).to be true
    end

    it "allows update for authenticated users" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.update?).to be true
    end

    it "allows destroy only for admins" do
      admin_policy = described_class.new(Workshop.new, user: admin_user)
      regular_policy = described_class.new(Workshop.new, user: regular_user)

      expect(admin_policy.destroy?).to be true
      expect(regular_policy.destroy?).to be false
    end
  end
end
