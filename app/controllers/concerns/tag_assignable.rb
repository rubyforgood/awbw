module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_associations(record, param_key: nil)
    key = param_key || record.model_name.param_key

    selected_category_ids = Array(params[key][:category_ids]).reject(&:blank?).map(&:to_i)
    selected_category_ids |= primary_category_ids(key)
    selected = Category.where(id: selected_category_ids).to_a

    categories_before = record.categories.to_a

    if params[key].key?(:managed_category_type_ids)
      # The form only edits certain category types (e.g. age ranges + workshop
      # settings). Preserve taggings of every other type the form never shows so
      # saving can't silently drop them — and assign the union so the join rows
      # for preserved categories stay intact (is_primary/legacy_id untouched).
      managed_type_ids = Array(params[key][:managed_category_type_ids]).reject(&:blank?).map(&:to_i)
      preserved = record.categories.reject { |category| managed_type_ids.include?(category.category_type_id) }
      record.categories = (preserved + selected).uniq
    else
      record.categories = selected
    end
    categories_after = record.categories.to_a

    sectors_changed = params[key].key?(:sector_ids)
    if sectors_changed
      sectors_before = record.sectors.to_a
      selected_sector_ids = Array(params[key][:sector_ids]).reject(&:blank?).map(&:to_i)
      selected_sector_ids |= primary_tag_ids(key, :primary_sector_id)
      record.sectors = Sector.where(id: selected_sector_ids)
      sectors_after = record.sectors.to_a
    end

    record.save!

    # Once category membership is set, split the AgeRange taggings into primary
    # and additional from the form's "Primary" toggles. Read raw (not via strong
    # params) like category_ids above, since it isn't a record attribute.
    if params[key].key?(:primary_age_category_ids) && record.respond_to?(:apply_primary_age_groups!)
      record.apply_primary_age_groups!(Array(params[key][:primary_age_category_ids]))
    end
    # The single-star primary picker (stories, story ideas) sends one id per kind.
    primary_changes = {}
    if params[key].key?(:primary_sector_id)
      primary_changes[:primary_sector] =
        assign_primary_tag(record.sectorable_items, :sector, primary_tag_ids(key, :primary_sector_id).first)
    end
    if params[key].key?(:primary_category_id)
      primary_changes[:primary_category] =
        assign_primary_tag(record.categorizable_items, :category, primary_category_ids(key).first)
    end

    # These memberships change outside the record's dirty tracking, so hand the
    # diff to the change log directly (a no-op when nothing actually moved).
    return unless record.respond_to?(:track_membership_changes)

    record.track_membership_changes(
      categories: membership_delta(categories_before, categories_after),
      sectors: (membership_delta(sectors_before, sectors_after) if sectors_changed),
      **primary_changes
    )
  end

  def primary_tag_ids(key, field)
    Array(params[key][field].presence).map(&:to_i).first(1)
  end

  # Only a story population (audience) category can be primary.
  def primary_category_ids(key)
    Category.story_populations.where(id: primary_tag_ids(key, :primary_category_id)).ids
  end

  # Returns the tags promoted/demoted, so the record's change log shows the primary moving.
  def assign_primary_tag(items, tag, primary_id)
    items.reload.each_with_object({ added: [], removed: [] }) do |item, delta|
      is_primary = item.public_send(:"#{tag}_id") == primary_id
      next if item.is_primary? == is_primary

      item.update!(is_primary:)
      delta[is_primary ? :added : :removed] << item.public_send(tag)
    end
  end

  def membership_delta(before, after)
    before = Array(before)
    after = Array(after)
    { added: after - before, removed: before - after }
  end
end
