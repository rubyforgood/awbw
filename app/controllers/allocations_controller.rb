class AllocationsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize!
    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      @allocations = @allocatable.allocations.includes(:source).order(created_at: :desc).paginate(page: params[:page], per_page: 25)
    else
      @allocations = Allocation.all.includes(:source).order(created_at: :desc).paginate(page: params[:page], per_page: 25)
    end
  end

  def new
    authorize!

    if params[:source_sgid].present?
      @source = GlobalID::Locator.locate_signed(params[:source_sgid])
    end

    @allocation = Allocation.new(source: @source)
    @event_registrations = EventRegistration.all.order(created_at: :desc).limit(100)
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

    if @allocation.source_type && @allocation.source_id
      @source = @allocation.source_type.constantize.find_by(id: @allocation.source_id)
    end

    @event_registrations = EventRegistration.all.order(created_at: :desc).limit(100)

    if @allocation.allocatable_type == "EventRegistration"
      unless validate_event_registration_cost(@allocation, amount_val)
        flash[:error] = @allocation.errors.full_messages.join(", ")
        render :new, status: :unprocessable_content
        return
      end
    end

    unless @source.present?
      @allocation.errors.add(:base, "Source is required")
      render :new, status: :unprocessable_content
      return
    end

    @source.with_lock do
      if @source.is_a?(Payment)
        remaining = @source.amount_cents_remaining
        if @allocation.amount > remaining
          @allocation.errors.add(:amount, "cannot exceed remaining amount (#{remaining})")
          render :new, status: :unprocessable_content
          return
        end

        if @allocation.save
          @source.update!(amount_cents_remaining: @source.amount_cents_remaining - amount_val)
          flash[:notice] = "Allocation created. $#{'%.2f' % @source.remaining_dollars} remaining on payment."
          redirect_to payment_path(@source)
        else
          Rails.logger.error "Allocation save failed: #{@allocation.errors.full_messages}"
          render :new, status: :unprocessable_content
        end
      end
    end
  end

  def revert
    authorize!

    @allocation = Allocation.find(params[:id])

    if @allocation.reverted?
      flash[:error] = "This allocation has already been reverted"
      redirect_to payment_path(@allocation.source)
      return
    end

    @revert = Allocation.new(
      source: @allocation.source,
      allocatable: @allocation.allocatable,
      amount: -@allocation.amount
    )

    if @revert.save
      @allocation.update!(reverted_id: @revert.id)

      payment = @allocation.source
      payment.with_lock do
        payment.update!(amount_cents_remaining: payment.amount_cents_remaining + @allocation.amount)
      end

      redirect_to payment_path(payment), notice: "Allocation reverted"
    else
      flash[:error] = @revert.errors.full_messages.join(", ")
      redirect_to payment_path(@allocation.source)
    end
  end

  private

  def validate_event_registration_cost(allocation, amount_val)
    return true unless allocation.allocatable.present?

    event_reg = allocation.allocatable
    event = event_reg.event
    return false if event.cost_cents.blank?

    current_allocated = event_reg.allocations_sum || 0
    new_total = current_allocated + amount_val

    if new_total > event.cost_cents
      remaining = [ event.cost_cents - current_allocated, 0 ].max
      allocation.errors.add(:base, "Cannot allocate more than remaining event cost. Remaining: $#{'%.2f' % (remaining / 100.0)}")
      return false
    end

    true
  end

  def allocation_params
    params.require(:allocation).permit(:source_type, :source_id, :allocatable_type, :allocatable_id, :amount_dollars)
  end
end
