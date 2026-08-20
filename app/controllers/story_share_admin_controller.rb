class StoryShareAdminController < ApplicationController
  # Admin page for curating the Story Share portal's nav menus by setting
  # story_share_position on sectors (top row) and audience categories (second
  # row). story_share_position is a plain integer (NOT the positioned gem), so
  # reordering renumbers it manually here.
  before_action :set_klass, only: [ :reorder, :add, :remove ]

  def show
    authorize! :story_share_admin, to: :show?
    @sectors = Sector.story_share_featured.to_a
    @categories = Category.story_share_featured.to_a
  end

  # Drag-and-drop: moves the record to the given 1-based position and renumbers
  # the rest. Driven by sortable_controller.js (PUT { position: N }).
  def reorder
    authorize! :story_share_admin, to: :reorder?
    featured = @klass.story_share_featured.to_a
    moved = featured.find { |record| record.id == params[:id].to_i }
    return head :not_found unless moved

    featured.delete(moved)
    featured.insert([ params[:position].to_i - 1, 0 ].max, moved)
    renumber(featured)
    head :ok
  end

  # Adds a sector/category to the menu at the end, then reloads so it appears in
  # the sortable list.
  def add
    authorize! :story_share_admin, to: :add?
    record = @klass.find(params[:id])
    max = @klass.story_share_featured.maximum(:story_share_position) || 0
    record.update_columns(story_share_position: max + 1)
    expire_menu_caches
    redirect_to story_share_admin_path, notice: "Added to the Story Share menu."
  end

  def remove
    authorize! :story_share_admin, to: :remove?
    record = @klass.find(params[:id])
    record.update_columns(story_share_position: nil)
    renumber(@klass.story_share_featured.to_a)
    redirect_to story_share_admin_path, notice: "Removed from the Story Share menu."
  end

  private

  def set_klass
    @klass = params[:type] == "category" ? Category : Sector
  end

  # Rewrite story_share_position to a gapless 1..n sequence in list order.
  # update_columns skips the positioned gem / validations (which only govern the
  # separate :position column), so we expire the portal nav caches ourselves.
  def renumber(records)
    @klass.transaction do
      records.each_with_index { |record, index| record.update_columns(story_share_position: index + 1) }
    end
    expire_menu_caches
  end

  def expire_menu_caches
    Rails.cache.delete("story_share_nav_sectors")
    Rails.cache.delete("story_share_audience_categories")
    Rails.cache.delete("story_share_focus_area_sectors")
  end
end
