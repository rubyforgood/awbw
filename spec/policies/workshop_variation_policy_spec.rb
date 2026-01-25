# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkshopVariationPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows admin users" do
      policy = described_class.new(WorkshopVariation, user: admin_user)
      expect(policy.index?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(WorkshopVariation, user: regular_user)
      expect(policy.index?).to be false
    end
  end

  describe "#show?" do
    let(:workshop_variation) { create(:workshop_variation) }

    it "allows any authenticated user" do
      policy = described_class.new(workshop_variation, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(WorkshopVariation.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#destroy?" do
    let(:workshop_variation) { create(:workshop_variation) }

    it "allows admin users" do
      policy = described_class.new(workshop_variation, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(workshop_variation, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "workshops scope" do
    let!(:published_workshop) { create(:workshop, inactive: false) }
    let!(:unpublished_workshop) { create(:workshop, inactive: true) }

    it "returns all workshops for admin users" do
      policy = described_class.new(Workshop, user: admin_user)
      scope = policy.apply_scope(Workshop, type: :workshops)
      expect(scope).to include(published_workshop, unpublished_workshop)
    end

    it "returns only published workshops for regular users" do
      policy = described_class.new(Workshop, user: regular_user)
      scope = policy.apply_scope(Workshop, type: :workshops)
      expect(scope).to include(published_workshop)
      expect(scope).not_to include(unpublished_workshop)
    end
  end
end
