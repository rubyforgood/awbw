require "rails_helper"

RSpec.describe StorySharesHelper, type: :helper do
  describe "#audience_tag_chip_class" do
    it "uses the age range chip for an age range category" do
      category = build(:category, category_type: build(:category_type, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE))
      expect(helper.audience_tag_chip_class(category)).to eq(StorySharesHelper::AGE_RANGE_TAG_CHIP)
    end

    it "uses the audience chip for a story population category" do
      category = build(:category, category_type: build(:category_type, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE))
      expect(helper.audience_tag_chip_class(category)).to eq(StorySharesHelper::AUDIENCE_TAG_CHIP)
    end
  end
end
