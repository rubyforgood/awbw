require "rails_helper"

RSpec.describe StaffTag, type: :model do
  it "requires a name" do
    expect(build(:staff_tag, name: nil)).not_to be_valid
  end

  it "enforces case-insensitive name uniqueness" do
    create(:staff_tag, name: "Highlight Roster")
    expect(build(:staff_tag, name: "highlight roster")).not_to be_valid
  end

  describe "publishing" do
    it "defaults to published" do
      expect(create(:staff_tag)).to be_published
    end

    it "scopes published vs unpublished" do
      published = create(:staff_tag)
      unpublished = create(:staff_tag, :unpublished)

      expect(StaffTag.published).to include(published)
      expect(StaffTag.published).not_to include(unpublished)
      expect(StaffTag.published(false)).to contain_exactly(unpublished)
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
