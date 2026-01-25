# frozen_string_literal: true

require "rails_helper"

RSpec.describe QuotePolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Quote, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:quote) { create(:quote) }

    it "allows any authenticated user" do
      policy = described_class.new(quote, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:quote) { create(:quote) }

    it "allows admin users" do
      policy = described_class.new(quote, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(quote, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "workshops scope" do
    let!(:active_workshop) { create(:workshop, inactive: false) }
    let!(:inactive_workshop) { create(:workshop, inactive: true) }

    it "returns all workshops for admin users" do
      policy = described_class.new(Workshop, user: admin_user)
      scope = policy.apply_scope(Workshop, type: :workshops)
      expect(scope).to include(active_workshop, inactive_workshop)
    end

    it "returns only active workshops for regular users" do
      policy = described_class.new(Workshop, user: regular_user)
      scope = policy.apply_scope(Workshop, type: :workshops)
      expect(scope).to include(active_workshop)
      expect(scope).not_to include(inactive_workshop)
    end
  end
end
