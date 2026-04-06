class AllocationsController < ApplicationController
  before_action :authenticate_user!

  def index
    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      @allocations = @allocatable.allocations.includes(:source)
    else
      @allocations = Allocation.all
    end
    authorize! @allocations
  end
end
