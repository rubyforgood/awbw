# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkshopPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }
  let(:owner_user) { create(:user, super_user: false) }
  let(:workshop) { create(:workshop, user: owner_user) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Workshop, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "allows any authenticated user" do
      policy = described_class.new(workshop, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(Workshop.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "allows admin users" do
      policy = described_class.new(workshop, user: admin_user)
      expect(policy.update?).to be true
    end

    it "allows workshop owners" do
      policy = described_class.new(workshop, user: owner_user)
      expect(policy.update?).to be true
    end

    it "denies regular users who don't own the workshop" do
      policy = described_class.new(workshop, user: regular_user)
      expect(policy.update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(workshop, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies workshop owners" do
      policy = described_class.new(workshop, user: owner_user)
      expect(policy.destroy?).to be false
    end

    it "denies regular users" do
      policy = described_class.new(workshop, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:published_workshop) { create(:workshop, inactive: false) }
    let!(:unpublished_workshop) { create(:workshop, inactive: true) }

    it "returns all workshops for admin users" do
      policy = described_class.new(Workshop, user: admin_user)
      scope = policy.apply_scope(Workshop, type: :relation)
      expect(scope).to include(published_workshop, unpublished_workshop)
    end

    it "returns only published workshops for regular users" do
      policy = described_class.new(Workshop, user: regular_user)
      scope = policy.apply_scope(Workshop, type: :relation)
      expect(scope).to include(published_workshop)
      expect(scope).not_to include(unpublished_workshop)
    end
  end
end
