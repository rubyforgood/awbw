class AllocationsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize!
    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      base = @allocatable.allocations
    else
      base = Allocation.search_by_params(params)
    end

    # Net total across the whole (unpaginated) filtered set, so the header shows
    # the true sum even when results span multiple pages. Summed on the base
    # scope (no :source includes — polymorphic associations can't be eager-loaded
    # for an aggregate).
    @allocations_total_cents = base.sum(:amount)
    @allocations = base.includes(:source).order(created_at: :desc).paginate(page: params[:page], per_page: 10)
    render :allocation_results if turbo_frame_request? && @allocatable.blank?
  end

  def new
    authorize!

    if params[:source_sgid].present?
      @source = GlobalID::Locator.locate_signed(params[:source_sgid])
    end

    @allocation = Allocation.new(source: @source)
  end

  def create
    authorize!

    amount_val = allocation_params[:amount_dollars].present? ? (allocation_params[:amount_dollars].to_d * 100).to_i : 0

    @allocation = Allocation.new(
      source_type: allocation_params[:source_type],
      source_id: allocation_params[:source_id],
      allocatable_type: allocation_params[:allocatable_type],
      allocatable_id: allocation_params[:allocatable_id],
      amount: amount_val
    )

    if @allocation.source_type.present? && @allocation.source_id
      @source = find_source(@allocation.source_type, @allocation.source_id)
    end

    unless @source.present?
      @allocation.errors.add(:base, "Source is required")
      render :new, status: :unprocessable_content
      return
    end

    @source.with_lock do
      if @source.respond_to?(:amount_cents_remaining) && @allocation.amount > @source.amount_cents_remaining
        @allocation.errors.add(:base, "Cannot exceed remaining amount ($#{@source.remaining_dollars})")

        flash.now[:error] = @allocation.errors.full_messages.join(", ")
        respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.replace("flash_now", partial: "shared/flash_messages"), status: :unprocessable_content }
            format.html { render :new, status: :unprocessable_content }
          end
        return
      end

      if @allocation.save
        flash[:notice] = "Allocation created."
        redirect_to source_path(@source)
      else
        flash.now[:error] = @allocation.errors.full_messages.join(", ")
        respond_to do |format|
            format.turbo_stream { render turbo_stream: turbo_stream.replace("flash_now", partial: "shared/flash_messages"), status: :unprocessable_content }
            format.html { render :new, status: :unprocessable_content }
          end
      end
    end
  end

  def revert
    @allocation = Allocation.find(params[:id])

    authorize! @allocation

    if @allocation.reverted?
      flash[:error] = "This allocation has already been reverted"
      redirect_to source_path(@allocation.source)
      return
    end

    @revert = Allocation.new(
      source: @allocation.source,
      allocatable: @allocation.allocatable,
      amount: -@allocation.amount
    )

    @allocation.source.with_lock do
      if @revert.save
        @allocation.update!(reverted_id: @revert.id)

        redirect_to source_path(@allocation.source), notice: "Allocation reverted"
      else
        flash[:error] = @revert.errors.full_messages.join(", ")
        redirect_to source_path(@allocation.source)
      end
    end
  end

  private

  def source_path(source)
    polymorphic_path(source.becomes(source.class.base_class))
  end

  def find_source(type, id)
    case type
    when "Payment" then Payment.find_by(id: id)
    when "Scholarship" then Scholarship.find_by(id: id)
    when "Refund" then Refund.find_by(id: id)
    when "Discount" then Discount.find_by(id: id)
    end
  end

  def allocation_params
    params.expect(allocation: [ :source_type, :source_id, :allocatable_type, :allocatable_id, :amount_dollars ])
  end
end
