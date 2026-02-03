class TagsController < ApplicationController
  def index
    authorize!
  end

  def sectors
    authorize! Sector, to: :tags_index?
    @sectors = Sector.published.order(:name)
  end

  def categories
    authorize! Category, to: :tags_index?
    @categories_by_type = Category
      .published
      .joins(:category_type)
      .select("categories.*, category_types.name AS category_type_name")
      .order("category_types.name, categories.position, categories.name")
      .to_a
      .group_by(&:category_type_name)
  end
end
