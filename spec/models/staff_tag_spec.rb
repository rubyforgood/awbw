require "rails_helper"

RSpec.describe StaffTag, type: :model do
  it "requires a name" do
    expect(build(:staff_tag, name: nil)).not_to be_valid
  end

  it "enforces case-insensitive name uniqueness" do
    create(:staff_tag, name: "Highlight Roster")
    expect(build(:staff_tag, name: "highlight roster")).not_to be_valid
  end

  describe "archiving" do
    it "toggles archived state" do
      tag = create(:staff_tag)
      expect(tag).not_to be_archived

      tag.archive!
      expect(tag.reload).to be_archived

      tag.unarchive!
      expect(tag.reload).not_to be_archived
    end

    it "scopes active vs archived" do
      active = create(:staff_tag)
      archived = create(:staff_tag, :archived)

      expect(StaffTag.active).to include(active)
      expect(StaffTag.active).not_to include(archived)
      expect(StaffTag.archived).to contain_exactly(archived)
    end
  end

  describe "taggings" do
    it "reaches tagged people through the polymorphic join" do
      tag = create(:staff_tag)
      person = create(:person)
      tag.staff_taggings.create!(staff_taggable: person)

      expect(tag.people).to contain_exactly(person)
    end

    it "won't destroy a tag that is still applied" do
      tag = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag)

      expect(tag.destroy).to be_falsey
      expect(tag.errors[:base]).to be_present
    end
  end
end
