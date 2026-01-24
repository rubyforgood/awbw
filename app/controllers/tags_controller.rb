class TagsController < ApplicationController
  def index
  end

  def sectors
    @sectors = Rails.cache.fetch("published_sectors_with_sectorable_items", expires_in: 1.month) do
      Sector
        .includes(:sectorable_items)
        .references(:sectorable_items)
        .published
        .distinct
        .order(:name)
        .to_a
    end
  end

  def categories
    @categories_by_type = Rails.cache.fetch("published_categories_by_type", expires_in: 1.month) do
      categories =
        Category
          .includes(:category_type, :categorizable_items)
          .references(:category_type, :categorizable_items)
          .published
          .select("categories.*, category_types.name AS category_type_name")
          .distinct
          .order(Arel.sql("category_type_name, categories.position, categories.name"))

      categories.group_by(&:category_type_name)
    end
  end
end
