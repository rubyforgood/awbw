class ScholarshipsController < ApplicationController
  before_action :set_scholarship, only: [ :show, :edit, :update, :destroy ]

  def show
    @scholarship = Scholarship.find(params[:id])
    authorize! @scholarship
  end

  def new
    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." unless @allocatable

    @scholarship = Scholarship.new(recipient: @allocatable.registrant)
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    authorize! @scholarship
  end

  def create
    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(scholarship_params.merge(recipient: @allocatable.registrant))
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    authorize! @scholarship

    if @scholarship.save
      redirect_to edit_scholarship_path(@scholarship), notice: "Scholarship created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
  end

  def update
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship

    if @scholarship.update(scholarship_params)
      redirect_to edit_scholarship_path(@scholarship), notice: "Scholarship updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    @scholarship.destroy!

    event = @allocatable.try(:event)
    redirect_to event ? manage_event_path(event) : scholarships_path,
                notice: "Scholarship removed."
  end

  private

  def set_scholarship
    @scholarship = Scholarship.find(params[:id])
  end

  def locate_allocatable
    sgid = params[:allocatable_sgid] || params.dig(:scholarship, :allocatable_sgid)
    GlobalID::Locator.locate_signed(sgid) if sgid
  end

  def scholarship_params
    params.require(:scholarship).permit(:amount_dollars, :amount_cents, :tasks_completed)
  end
end
