# frozen_string_literal: true

require "rails_helper"

RSpec.describe StoryPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Story, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:story) { create(:story) }

    it "allows any authenticated user" do
      policy = described_class.new(story, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(Story.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#destroy?" do
    let(:story) { create(:story) }

    it "allows admin users" do
      policy = described_class.new(story, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(story, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:published_story) { create(:story, published: true) }
    let!(:unpublished_story) { create(:story, published: false) }

    it "returns all stories for admin users" do
      policy = described_class.new(Story, user: admin_user)
      scope = policy.apply_scope(Story, type: :relation)
      expect(scope).to include(published_story, unpublished_story)
    end

    it "returns only published stories for regular users" do
      policy = described_class.new(Story, user: regular_user)
      scope = policy.apply_scope(Story, type: :relation)
      expect(scope).to include(published_story)
      expect(scope).not_to include(unpublished_story)
    end
  end
end
