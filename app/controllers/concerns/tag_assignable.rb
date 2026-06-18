module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_associations(record, param_key: nil)
    key = param_key || record.model_name.param_key

    selected_category_ids = Array(params[key][:category_ids]).reject(&:blank?).map(&:to_i)
    record.categories = Category.where(id: selected_category_ids)

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
