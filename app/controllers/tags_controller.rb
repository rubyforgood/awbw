class TagsController < ApplicationController
  include AhoyTracking

  skip_before_action :authenticate_user!, only: [ :index, :sectors, :categories ]

  def index
    authorize!
    track_view("tags", { page: "index" })
  end

  def sectors
    authorize! Sector, to: :tags_index?
    @sectors = Sector.published.has_published_taggings.order(:name)
  end

  def categories
    authorize! Category, to: :tags_index?
    @categories_by_type = Category
      .published
      .has_published_taggings
      .joins(:category_type)
      .select("categories.*, category_types.name AS category_type_name")
      .order("category_types.name, categories.position, categories.name")
      .to_a
      .group_by(&:category_type_name)
  end
end
