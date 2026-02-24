module TagAssignable
  extend ActiveSupport::Concern

  private

  def assign_associations(record, param_key: nil)
    key = param_key || record.model_name.param_key

    selected_category_ids = Array(params[key][:category_ids]).reject(&:blank?).map(&:to_i)
    record.categories = Category.where(id: selected_category_ids)

    selected_sector_ids = Array(params[key][:sector_ids]).reject(&:blank?).map(&:to_i)
    record.sectors = Sector.where(id: selected_sector_ids)

    record.save!
  end
end
