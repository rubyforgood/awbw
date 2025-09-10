# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Permission) do
  describe "associations" do
    it { is_expected.to(have_many(:user_permissions)) }
    it { is_expected.to(have_many(:users).through(:user_permissions)) }
  end

  it "is valid with valid attributes" do
    expect(build(:permission)).to(be_valid)
  end

  describe "#name" do
    it "returns the security_cat" do
      permission = build(:permission, security_cat: "Test Category")
      expect(permission.name).to(eq("Test Category"))
    end
  end
end
