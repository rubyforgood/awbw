module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_associations(record, param_key: nil)
    key = param_key || record.model_name.param_key

    selected_category_ids = Array(params[key][:category_ids]).reject(&:blank?).map(&:to_i)
    selected_category_ids |= primary_tag_ids(key, :primary_category_id)
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
    if primary_tag_editable?(key, :primary_sector_id)
      assign_primary_tag(record.sectorable_items, :sector_id, primary_tag_ids(key, :primary_sector_id).first)
    end
    if primary_tag_editable?(key, :primary_category_id)
      assign_primary_tag(record.categorizable_items, :category_id, primary_tag_ids(key, :primary_category_id).first)
    end

    # These memberships change outside the record's dirty tracking, so hand the
    # diff to the change log directly (a no-op when nothing actually moved).
    return unless record.respond_to?(:track_membership_changes)

    record.track_membership_changes(
      categories: membership_delta(categories_before, categories_after),
      sectors: (membership_delta(sectors_before, sectors_after) if sectors_changed)
    )
  end

  def primary_tag_ids(key, field)
    return [] unless primary_tag_editable?(key, field)

    Array(params[key][field].presence).map(&:to_i).first(1)
  end

  # Only admins curate the primary star; anyone else's submission leaves it untouched.
  def primary_tag_editable?(key, field)
    current_user&.super_user? && params[key].key?(field)
  end

  def assign_primary_tag(items, foreign_key, primary_id)
    items.reload.each do |item|
      is_primary = item.public_send(foreign_key) == primary_id
      item.update!(is_primary:) if item.is_primary? != is_primary
    end
  end

  def membership_delta(before, after)
    before = Array(before)
    after = Array(after)
    { added: after - before, removed: before - after }
  end
end
