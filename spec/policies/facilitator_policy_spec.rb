# frozen_string_literal: true

require "rails_helper"

RSpec.describe FacilitatorPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Facilitator, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:facilitator) { create(:facilitator) }

    it "allows any authenticated user" do
      policy = described_class.new(facilitator, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:facilitator) { create(:facilitator) }

    it "allows admin users" do
      policy = described_class.new(facilitator, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(facilitator, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "projects scope" do
    let(:project) { create(:project) }

    before do
      create(:project_user, user: regular_user, project: project)
    end

    it "returns all active projects for admin users" do
      policy = described_class.new(Project, user: admin_user)
      scope = policy.apply_scope(Project, type: :projects)
      expect(scope).to include(project)
    end

    it "returns only user's projects for regular users" do
      other_project = create(:project)
      policy = described_class.new(Project, user: regular_user)
      scope = policy.apply_scope(Project, type: :projects)
      expect(scope).to include(project)
      expect(scope).not_to include(other_project)
    end
  end
end
