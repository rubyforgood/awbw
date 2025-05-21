class WorkshopSearchController < ApplicationController
  before_action :load_metadata
  def new
    @workshops = Workshop.limit(50).includes(:workshop_logs).recent
    load_sortable_fields
    load_metadata
  end

  def create
    process_search
    load_sortable_fields
    load_metadata
    render :new
  end

  private

  def process_search
    @params = search_params
    @query = search_params[:query]
    @workshops = Workshops::Search.new.search(search_params)
  end

  def load_sortable_fields
    @sortable_fields = [
      WindowsType.all,
      :rating,
      :warm_up_and_relaxation,
      :led_count
    ].flatten.select { |name| puts name.class; name != :combined  }
  end

  def load_metadata
    @metadata = Metadatum.all.includes(:categories).decorate
    @sectors = Sector.all
  end

  def search_params
    params[:search]
  end
end
