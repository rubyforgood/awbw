require "rails_helper"

RSpec.describe StaffTagging, type: :model do
  it "is valid with a tag and a taggable" do
    expect(build(:staff_tagging)).to be_valid
  end

  it "prevents tagging the same record with the same tag twice" do
    person = create(:person)
    tag = create(:staff_tag)
    create(:staff_tagging, staff_tag: tag, staff_taggable: person)

    dup = build(:staff_tagging, staff_tag: tag, staff_taggable: person)
    expect(dup).not_to be_valid
    expect(dup.errors[:staff_tag_id]).to be_present
  end

  it "records who applied the tag" do
    admin = create(:user, :admin)
    tagging = create(:staff_tagging, created_by: admin)

    expect(tagging.created_by).to eq(admin)
  end
end
