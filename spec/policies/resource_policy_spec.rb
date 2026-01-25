# frozen_string_literal: true

require "rails_helper"

RSpec.describe ResourcePolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Resource, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:resource) { create(:resource) }

    it "allows any authenticated user" do
      policy = described_class.new(resource, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:resource) { create(:resource) }

    it "allows admin users" do
      policy = described_class.new(resource, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(resource, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    it "returns all resources for admin users" do
      policy = described_class.new(Resource, user: admin_user)
      scope = policy.apply_scope(Resource, type: :relation)
      expect(scope).to eq(Resource.all)
    end

    it "returns only published kinds for regular users" do
      policy = described_class.new(Resource, user: regular_user)
      scope = policy.apply_scope(Resource, type: :relation)
      expect(scope.to_sql).to include("kind")
    end
  end
end
