# frozen_string_literal: true

require "rails_helper"

RSpec.describe CommunityNewsPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(CommunityNews, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:community_news) { create(:community_news) }

    it "allows any authenticated user" do
      policy = described_class.new(community_news, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:community_news) { create(:community_news) }

    it "allows admin users" do
      policy = described_class.new(community_news, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(community_news, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:published_news) { create(:community_news, published: true) }
    let!(:unpublished_news) { create(:community_news, published: false) }

    it "returns all news for admin users" do
      policy = described_class.new(CommunityNews, user: admin_user)
      scope = policy.apply_scope(CommunityNews, type: :relation)
      expect(scope).to include(published_news, unpublished_news)
    end

    it "returns only published news for regular users" do
      policy = described_class.new(CommunityNews, user: regular_user)
      scope = policy.apply_scope(CommunityNews, type: :relation)
      expect(scope).to include(published_news)
      expect(scope).not_to include(unpublished_news)
    end
  end
end
