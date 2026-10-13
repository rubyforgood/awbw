# Single-primary category rule for records tagged through categorizable_items
# (Story, StoryIdea) — the category counterpart of SectorsTaggable. Any category
# can be primary; the story forms offer the star only on the audience tag set.
module CategoriesTaggable
  extend ActiveSupport::Concern

  STORY_POPULATION_CATEGORY_TYPE = "StoryPopulation"
  # "Who is this story about?" — age ranges (Children, Teens, …) plus story
  # populations (Self, Colleagues, …), offered together as one tag set.
  AUDIENCE_CATEGORY_TYPES = [ AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE, STORY_POPULATION_CATEGORY_TYPE ].freeze

  included do
    validate :at_most_one_primary_category
  end

  def primary_category
    categorizable_items.find(&:is_primary?)&.category
  end

  def audience_categories
    categories.audiences
  end

  private

  def live_primary_category_items
    categorizable_items.reject(&:marked_for_destruction?).select(&:is_primary?)
  end

  def at_most_one_primary_category
    return if live_primary_category_items.size <= 1

    errors.add(:base, "Only one category can be marked as primary")
  end
end
