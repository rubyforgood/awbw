require "rails_helper"

RSpec.describe Role do
  let(:user) { create(:user) }
  let(:organization) { create(:organization) }

  it "is valid as a global member" do
    expect(build(:role, user: user, role: "member")).to be_valid
  end

  it "is valid as an organization manager" do
    expect(build(:role, user: user, role: "manager", roleable: organization)).to be_valid
  end

  it "rejects a global role with a roleable record" do
    role = build(:role, user: user, role: "member", roleable: organization)

    expect(role).not_to be_valid
    expect(role.errors[:roleable]).to be_present
  end

  it "requires a roleable record for a resource role" do
    role = build(:role, user: user, role: "manager")

    expect(role).not_to be_valid
    expect(role.errors[:roleable]).to be_present
  end

  it "rejects an unknown role" do
    expect(build(:role, user: user, role: "owner")).not_to be_valid
  end

  it "rejects a duplicate assignment" do
    create(:role, user: user, role: "member")

    expect(build(:role, user: user, role: "member")).not_to be_valid
  end
end
