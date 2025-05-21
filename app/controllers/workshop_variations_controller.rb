class WorkshopVariationsController < ApplicationController
  def show
    @workshop_variation = WorkshopVariation.find(params[:id]).decorate
    @workshop = @workshop_variation.workshop.decorate
    @bookmark = current_user.bookmarks.find_by(bookmarkable: @workshop)
    @new_bookmark = @workshop.bookmarks.build
    @quotes = @workshop.quotes
    @workshop_variations = @workshop.workshop_variations
    @sectors = @workshop.sectors
  end
end
