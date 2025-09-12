class ResourcesDecorator < Draper::CollectionDecorator
  delegate :current_page, :per_page, :offset, :total_entries, :total_pages

  def search_page
    h.params[:search] ? h.params[:search][:page] : 1
  end
end
