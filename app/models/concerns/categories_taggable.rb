# Single-primary category rule for records tagged through categorizable_items
# (Story, StoryIdea) — the category counterpart of SectorsTaggable. Only an
# audience category (AgeRange or StoryPopulation) can be primary, mirroring how a
# person's primary is limited to age ranges. The form's single star is the first
# line of defense; this guards imports and the console.
module CategoriesTaggable
  extend ActiveSupport::Concern

  STORY_POPULATION_CATEGORY_TYPE = "StoryPopulation"
  # "Who is this story about?" — age ranges (Children, Teens, …) plus story
  # populations (Self, Colleagues, …), offered together as one tag set.
  AUDIENCE_CATEGORY_TYPES = [ AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE, STORY_POPULATION_CATEGORY_TYPE ].freeze

  included do
    validate :at_most_one_primary_category
    validate :primary_category_is_an_audience
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

    errors.add(:base, "Only one \"who is this story about\" tag can be marked as primary")
  end

  def primary_category_is_an_audience
    return if live_primary_category_items.all? { |item| item.category&.category_type&.name.in?(AUDIENCE_CATEGORY_TYPES) }

    errors.add(:base, "Only an age range or story population can be marked as primary")
  end
end
