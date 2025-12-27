class TagsController < ApplicationController
  def index
  end

  def sectors
    @sectors =
      Sector
        .includes(:sectorable_items)
        .references(:sectorable_items)
        .published
        .distinct
        .order(:name)
  end

  def categories
    categories =
      Category
        .includes(:category_type, :categorizable_items)
        .references(:category_type, :categorizable_items)
        .published
        .select("categories.*, metadata.name AS category_type_name")
        .distinct
        .order("category_type_name ASC, categories.name ASC")

    @categories_by_type = categories.group_by(&:category_type_name)
  end
end
