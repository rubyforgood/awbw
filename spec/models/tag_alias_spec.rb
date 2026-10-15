require "rails_helper"

RSpec.describe TagAlias, type: :model do
  let(:sector) { create(:sector, name: "Domestic Violence") }

  it "is valid when it names a tag" do
    expect(build(:tag_alias, aliasable: sector)).to be_valid
  end

  it "is valid when it names nothing on purpose" do
    expect(build(:tag_alias, aliasable: nil, ignored: true)).to be_valid
  end

  it "rejects a term that neither names a tag nor is ignored" do
    expect(build(:tag_alias, aliasable: nil, ignored: false)).not_to be_valid
  end

  it "rejects a term that both names a tag and is ignored" do
    expect(build(:tag_alias, aliasable: sector, ignored: true)).not_to be_valid
  end

  it "records a term once per tag, whatever its case or spacing" do
    create(:tag_alias, name: "Student Services", aliasable: sector)

    expect(build(:tag_alias, name: "  student   services ", aliasable: sector)).not_to be_valid
  end

  it "lets two tags share a term, for a term that names both" do
    other = create(:sector, name: "Education")
    create(:tag_alias, name: "C & T", aliasable: sector)

    expect(build(:tag_alias, name: "C & T", aliasable: other)).to be_valid
  end

  it "only accepts a system it could have come from" do
    expect(build(:tag_alias, aliasable: sector, source: "spreadsheet")).not_to be_valid
  end
end
