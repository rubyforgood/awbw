class FeaturedStoriesController < ApplicationController
  def index
    authorize! Story, to: :reorder?
    # Operate on the full featured set (published or not) so the drag-and-drop
    # index lines up exactly with the positioning scope (positioned on: :featured).
    @stories = Story.where(featured: true).order(:position).decorate
  end

  def update
    story = Story.find(params[:id])
    authorize! story, to: :reorder?
    story.update!(position: params[:position])
    head :no_content
  end
end
