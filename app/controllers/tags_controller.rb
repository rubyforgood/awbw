class TagsController < ApplicationController
  include AhoyTracking

  skip_before_action :authenticate_user!, only: [ :index, :sectors, :categories ]

  def index
    authorize!
    @sectors = authorized_scope(Sector.all, as: :taggable).order(:name)
    @categories = authorized_scope(Category.all, as: :taggable)
      .joins(:category_type)
      .select("categories.*, category_types.name AS category_type_name")
      .distinct
      .order("category_type_name ASC, categories.name ASC")
    @categories_by_type = @categories.to_a.group_by(&:category_type_name)
    # Admin-only: relation_scope returns none for everyone else, so the section hides.
    @staff_tags = authorized_scope(StaffTag.all).published.ordered
    track_view("tags", { page: "index" })
  end

  def sectors
    authorize! Sector, to: :tags_index?
    @sectors = authorized_scope(Sector.all, as: :taggable).order(:name)
  end

  def categories
    authorize! Category, to: :tags_index?
    @categories_by_type = authorized_scope(Category.all, as: :taggable)
      .joins(:category_type)
      .select("categories.*, category_types.name AS category_type_name")
      .order("category_types.name, categories.position, categories.name")
      .to_a
      .group_by(&:category_type_name)
  end
end
