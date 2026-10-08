# Single-primary category rule for records tagged through categorizable_items
# (Story, StoryIdea) — the category counterpart of SectorsTaggable. The form's
# single-star UI is the first line of defense; this guards imports and the console.
module CategoriesTaggable
  extend ActiveSupport::Concern

  included do
    validate :at_most_one_primary_category
  end

  def primary_category
    categorizable_items.find(&:is_primary?)&.category
  end

  private

  def at_most_one_primary_category
    primary_count = categorizable_items.reject(&:marked_for_destruction?).count(&:is_primary?)
    return if primary_count <= 1

    errors.add(:base, "Only one category can be marked as primary")
  end
end
