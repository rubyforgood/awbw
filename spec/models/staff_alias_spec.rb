require "rails_helper"

RSpec.describe StaffAlias, type: :model do
  let(:user) { create(:user) }

  it "is valid when it names a user" do
    expect(build(:staff_alias, user:)).to be_valid
  end

  it "is valid when it names no one on purpose" do
    expect(build(:staff_alias, :ignored)).to be_valid
  end

  it "rejects a name that neither names a user nor is ignored" do
    expect(build(:staff_alias, user: nil)).not_to be_valid
  end

  it "rejects a name that both names a user and is ignored" do
    expect(build(:staff_alias, user:, ignored: true)).not_to be_valid
  end

  it "records a name once, whatever its case or spacing" do
    create(:staff_alias, name: "Jamie Rivera", user:)

    expect(build(:staff_alias, name: "  jamie   rivera ", user: create(:user))).not_to be_valid
  end

  it "goes with the user it names" do
    create(:staff_alias, user:)

    expect { user.destroy }.to change(described_class, :count).by(-1)
  end
end
