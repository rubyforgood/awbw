class TagsController < ApplicationController
  def index
  end

  def sectors
    @sectors = Sector.published.order(:name)
  end

  def categories
    @categories_by_type = Category
      .published
      .joins(:category_type)
      .select("categories.*, category_types.name AS category_type_name")
      .order("category_types.name, categories.position, categories.name")
      .to_a
      .group_by(&:category_type_name)
  end
end
