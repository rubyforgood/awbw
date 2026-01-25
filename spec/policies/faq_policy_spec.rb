# frozen_string_literal: true

require "rails_helper"

RSpec.describe FaqPolicy do
  let(:admin_user) { create(:user, super_user: true) }
  let(:regular_user) { create(:user, super_user: false) }

  describe "#index?" do
    it "allows any authenticated user" do
      policy = described_class.new(Faq, user: regular_user)
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    let(:faq) { create(:faq) }

    it "allows any authenticated user" do
      policy = described_class.new(faq, user: regular_user)
      expect(policy.show?).to be true
    end
  end

  describe "#destroy?" do
    let(:faq) { create(:faq) }

    it "allows admin users" do
      policy = described_class.new(faq, user: admin_user)
      expect(policy.destroy?).to be true
    end

    it "denies regular users" do
      policy = described_class.new(faq, user: regular_user)
      expect(policy.destroy?).to be false
    end
  end

  describe "scope" do
    let!(:active_faq) { create(:faq, inactive: false) }
    let!(:inactive_faq) { create(:faq, inactive: true) }

    it "returns all FAQs for admin users" do
      policy = described_class.new(Faq, user: admin_user)
      scope = policy.apply_scope(Faq, type: :relation)
      expect(scope).to include(active_faq, inactive_faq)
    end

    it "returns only active FAQs for regular users" do
      policy = described_class.new(Faq, user: regular_user)
      scope = policy.apply_scope(Faq, type: :relation)
      expect(scope).to include(active_faq)
      expect(scope).not_to include(inactive_faq)
    end
  end
end
