# Shared age-group tagging for records that carry categorizable_items
# (Person, Organization). AgeRange categories are tagged like any other
# category; the categorizable_items.is_primary flag splits them into the
# "primary" age groups a respondent serves and the "additional" ones — the same
# primary/additional distinction sectors get via sectorable_items.is_primary.
module AgeGroupTaggable
  extend ActiveSupport::Concern

  AGE_RANGE_CATEGORY_TYPE = "AgeRange"

  # AgeRange categories tagged on this record, split by the primary flag and
  # returned in display order. Filters the categorizable_items association in
  # Ruby (like the sectors index does with sectorable_items) so the result rides
  # on eager-loaded associations instead of issuing a query per record — which
  # matters when an organization aggregates these across many affiliated people.
  def primary_age_groups
    age_range_categories(primary: true)
  end

  def additional_age_groups
    age_range_categories(primary: false)
  end

  # Backs the edit form's "Primary" toggles — which currently-tagged AgeRange
  # categories are marked primary.
  def primary_age_category_ids
    primary_age_groups.map(&:id)
  end

  # Flip is_primary on the AgeRange categorizable_items to match the given set.
  # Runs after category membership has been assigned (the edit-form flow), so it
  # only updates existing items rather than creating them.
  def apply_primary_age_groups!(primary_category_ids)
    primary = sanitize_age_ids(primary_category_ids).to_set
    age_range_categorizable_items.includes(:category).find_each do |item|
      desired = primary.include?(item.category_id)
      item.update!(is_primary: desired) if item.is_primary? != desired
    end
    categorizable_items.reset
  end

  # Additively tag AgeRange categories as primary/additional without disturbing
  # other taggings — used by registration, where a respondent may add to age
  # groups recorded on a prior submission. A category named in both lists is
  # treated as primary.
  def tag_age_groups(primary_ids:, additional_ids:)
    primary = sanitize_age_ids(primary_ids)
    additional = sanitize_age_ids(additional_ids) - primary
    upsert_age_items(primary, is_primary: true)
    upsert_age_items(additional, is_primary: false)
    categorizable_items.reset
  end

  private

  def age_range_categories(primary:)
    categorizable_items
      .select { |item| item.is_primary? == primary && age_range_item?(item) }
      .map(&:category)
      .sort_by { |category| [ category.position || 0, category.name.to_s ] }
  end

  def age_range_item?(item)
    item.category&.category_type&.name == AGE_RANGE_CATEGORY_TYPE
  end

  def age_range_categorizable_items
    categorizable_items
      .joins(category: :category_type)
      .where(category_types: { name: AGE_RANGE_CATEGORY_TYPE })
  end

  def upsert_age_items(category_ids, is_primary:)
    Category.where(id: category_ids).find_each do |category|
      item = categorizable_items.find_or_initialize_by(category: category)
      item.is_primary = is_primary
      item.save!
    end
  end

  def sanitize_age_ids(ids)
    Array(ids).reject(&:blank?).map(&:to_i)
  end
end
