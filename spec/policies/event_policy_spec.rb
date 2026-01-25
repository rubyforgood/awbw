# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }
  let(:creator_user) { create(:user, super_user: false) }
  let(:event) { create(:event, created_by: creator_user) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Event, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "allows any authenticated user" do
      policy = described_class.new(event, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#create?" do
    it "allows any authenticated user" do
      policy = described_class.new(Event.new, user: regular_user)
      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "allows admin users" do
      policy = described_class.new(event, user: admin_user)
      expect(policy.update?).to be true
    end

    it "allows event creators" do
      policy = described_class.new(event, user: creator_user)
      expect(policy.update?).to be true
    end

    it "denies regular users who didn't create the event" do
      policy = described_class.new(event, user: regular_user)
      expect(policy.update?).to be false
    end
  end

  describe "#destroy?" do
    it "allows admin users" do
      policy = described_class.new(event, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies event creators" do
      policy = described_class.new(event, user: creator_user)
      expect(policy.destroy?).to be false
    end

    it "denies regular users" do
      policy = described_class.new(event, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:published_event) { create(:event, publicly_visible: true) }
    let!(:unpublished_event) { create(:event, publicly_visible: false) }

    it "returns all events for admin users" do
      policy = described_class.new(Event, user: admin_user)
      scope = policy.apply_scope(Event, type: :relation)
      expect(scope).to include(published_event, unpublished_event)
    end

    it "returns only published events for regular users" do
      policy = described_class.new(Event, user: regular_user)
      scope = policy.apply_scope(Event, type: :relation)
      expect(scope).to include(published_event)
      expect(scope).not_to include(unpublished_event)
    end
  end
end
