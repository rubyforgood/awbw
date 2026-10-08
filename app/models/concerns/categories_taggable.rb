# Single-primary category rule for records tagged through categorizable_items
# (Story, StoryIdea) — the category counterpart of SectorsTaggable. Only a
# StoryPopulation (audience) category can be primary, mirroring how a person's
# primary is limited to age ranges. The form's single star is the first line of
# defense; this guards imports and the console.
module CategoriesTaggable
  extend ActiveSupport::Concern

  # StoryPopulation categories describe who a story is about (Children, Teens,
  # Adults, …) — the portal's audience facet.
  AUDIENCE_CATEGORY_TYPE = "StoryPopulation"

  included do
    validate :at_most_one_primary_category
    validate :primary_category_is_an_audience
  end

  def primary_category
    categorizable_items.find(&:is_primary?)&.category
  end

  private

  def live_primary_category_items
    categorizable_items.reject(&:marked_for_destruction?).select(&:is_primary?)
  end

  def at_most_one_primary_category
    return if live_primary_category_items.size <= 1

    errors.add(:base, "Only one story population can be marked as primary")
  end

  def primary_category_is_an_audience
    return if live_primary_category_items.all? { |item| item.category&.category_type&.name == AUDIENCE_CATEGORY_TYPE }

    errors.add(:base, "Only a story population category can be marked as primary")
  end
end
