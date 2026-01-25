# frozen_string_literal: true

require "rails_helper"

RSpec.describe TutorialPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Tutorial, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:tutorial) { create(:tutorial) }

    it "allows any authenticated user" do
      policy = described_class.new(tutorial, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:tutorial) { create(:tutorial) }

    it "allows admin users" do
      policy = described_class.new(tutorial, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(tutorial, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:published_tutorial) { create(:tutorial, published: true) }
    let!(:unpublished_tutorial) { create(:tutorial, published: false) }

    it "returns all tutorials for admin users" do
      policy = described_class.new(Tutorial, user: admin_user)
      scope = policy.apply_scope(Tutorial, type: :relation)
      expect(scope).to include(published_tutorial, unpublished_tutorial)
    end

    it "returns only published tutorials for regular users" do
      policy = described_class.new(Tutorial, user: regular_user)
      scope = policy.apply_scope(Tutorial, type: :relation)
      expect(scope).to include(published_tutorial)
      expect(scope).not_to include(unpublished_tutorial)
    end
  end
end
