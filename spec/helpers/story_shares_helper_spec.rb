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

  describe "#audience_pill_colors" do
    it "uses rust orange for an age range category" do
      category = build(:category, category_type: build(:category_type, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE))
      expect(helper.audience_pill_colors(category)).to eq(StorySharesHelper::AGE_RANGE_COLORS)
    end

    it "uses yellow for a story population category" do
      category = build(:category, category_type: build(:category_type, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE))
      expect(helper.audience_pill_colors(category)).to eq(StorySharesHelper::STORY_POPULATION_COLORS)
    end
  end

  describe "#audience_tagging_label_colors" do
    it "gives an age range category rust orange with white text" do
      category = build(:category, category_type: build(:category_type, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE))
      expect(helper.audience_tagging_label_colors(category)).to include(bg_color: "bg-brand-rust", text_color: "text-white")
    end

    it "gives a story population category yellow" do
      category = build(:category, category_type: build(:category_type, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE))
      expect(helper.audience_tagging_label_colors(category)).to include(bg_color: "bg-brand-amber-100", text_color: "text-brand-amber-800")
    end
  end
end
