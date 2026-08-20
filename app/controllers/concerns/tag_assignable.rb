module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_associations(record, param_key: nil)
    key = param_key || record.model_name.param_key

    selected_category_ids = Array(params[key][:category_ids]).reject(&:blank?).map(&:to_i)
    selected = Category.where(id: selected_category_ids).to_a

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

    if params[key].key?(:sector_ids)
      selected_sector_ids = Array(params[key][:sector_ids]).reject(&:blank?).map(&:to_i)
      record.sectors = Sector.where(id: selected_sector_ids)
    end

    record.save!

    # Once category membership is set, split the AgeRange taggings into primary
    # and additional from the form's "Primary" toggles. Read raw (not via strong
    # params) like category_ids above, since it isn't a record attribute.
    if params[key].key?(:primary_age_category_ids) && record.respond_to?(:apply_primary_age_groups!)
      record.apply_primary_age_groups!(Array(params[key][:primary_age_category_ids]))
    end
  end
end
