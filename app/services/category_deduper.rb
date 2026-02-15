# frozen_string_literal: true

class CategoryDeduper < BaseDeduper
  # Public alias for backwards compatibility
  def merge_categories(category_to_keep, category_to_delete)
    merge(category_to_keep, category_to_delete)
  end

  private

  def model_class = Category
  def join_class = CategorizableItem
  def foreign_key = :category_id
  def polymorphic_type_column = :categorizable_type
  def polymorphic_id_column = :categorizable_id
end
