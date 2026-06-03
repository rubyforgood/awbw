class DiscountsController < ApplicationController
  def show
    @discount = Discount.find(params[:id])
    authorize! @discount
  end

  def create
    authorize!

    allocatable = locate_allocatable
    unless allocatable
      redirect_to allocations_path, alert: "Allocatable not found." and return
    end

    @discount = Discount.new(discount_params)

    ActiveRecord::Base.transaction do
      @discount.save!
      Allocation.create!(
        source: @discount,
        allocatable: allocatable,
        amount: @discount.amount_cents
      )
    end

    redirect_to allocations_path(allocatable_sgid: allocatable.to_sgid.to_s),
                notice: "Discount created."

  rescue ActiveRecord::RecordInvalid
    redirect_to allocations_path(allocatable_sgid: allocatable&.to_sgid.to_s),
                alert: "Failed to create discount."
  end

  def destroy
    @discount = Discount.find(params[:id])
    authorize! @discount

    allocatable = @discount.allocations.first&.allocatable
    @discount.destroy!

    redirect_to allocations_path(allocatable_sgid: allocatable&.to_sgid&.to_s),
                notice: "Discount deleted."
  end

  def allocation_form
    authorize!

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def discount_params
    params.require(:discount).permit(:amount_dollars)
  end

  def locate_allocatable
    GlobalID::Locator.locate_signed(params[:discount][:allocatable_sgid]) if params[:discount]&.dig(:allocatable_sgid)
  end
end
