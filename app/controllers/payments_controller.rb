class PaymentsController < ApplicationController
  PERMITTED_PAYMENT_TYPES = %w[CashPayment CheckPayment ExternalProcessorPayment].freeze
  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 10

    if turbo_frame_request?
      @payments = Payment.search_by_params(params).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
      render :payment_results
    else
      @payments = Payment.search_by_params(params).order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
    end
  end

  def new
    authorize!
    payment_type = params[:type]
    unless PERMITTED_PAYMENT_TYPES.include?(payment_type)
      redirect_to payments_path, alert: "Invalid payment type" and return
    end
    @payment = permitted_payment_type(payment_type).new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      if @allocatable.is_a?(EventRegistration)
        @payment.person = @allocatable.registrant
      end
    end
  end

  def create
    authorize!
    payment_class = permitted_payment_type(params[:payment][:type])

    unless payment_class
      @payment = Payment.new(payment_params.except(:allocatable_sgid, :type))
      @payment.errors.add(:type, "is not a valid payment type")
      render :new, status: :unprocessable_content and return
    end

    allocatable = locate_allocatable

    begin
      if allocatable.present?
        payment_attrs = build_payment_attributes(payment_params, allocatable)
        @payment = payment_class.new(payment_attrs)

        process_allocation!(@payment, allocatable)

        flash[:notice] = "Allocation created. $#{'%.2f' % @payment.reload.remaining_dollars} remaining on payment."
        redirect_path = allocations_path(allocatable_sgid: allocatable.to_sgid.to_s)
      else
        @payment = payment_class.new(payment_params.except(:allocatable_sgid, :type))
        @payment.save!
        redirect_path = payments_path
      end

      respond_to do |format|
        format.turbo_stream { redirect_to redirect_path }
        format.html { redirect_to redirect_path, notice: "Payment was successfully created." }
      end

    rescue ActiveRecord::RecordInvalid => e
      if allocatable.present?
        @allocatable = allocatable
        flash.now[:error] = @payment.errors.full_messages.join(", ")
        respond_to do |format|
          format.turbo_stream { render status: :unprocessable_content }
          format.html { render :new, status: :unprocessable_content }
        end
      else
        flash[:error] = @payment.errors.full_messages.join(", ")
        render :new, status: :unprocessable_content
      end
    end
  end

  def show
    @payment = Payment.find(params[:id])
    @allocations = @payment.allocations.order(created_at: :desc)
    @refunds = @payment.refunds.order(created_at: :desc)
    authorize! @payment, with: PaymentPolicy
  end

  def allocation_form
    authorize!
    payment_type = params[:type].presence
    unless PERMITTED_PAYMENT_TYPES.include?(payment_type)
      head :unprocessable_content and return
    end
    @payment = permitted_payment_type(payment_type).new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      if @allocatable.is_a?(EventRegistration)
        @payment.person = @allocatable.registrant
      end
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def permitted_payment_type(type)
    return nil unless type.present? && PERMITTED_PAYMENT_TYPES.include?(type)
    type.constantize
  end

  def payment_params
    params.require(:payment).permit(:type, :payer_type, :person_id, :organization_id, :amount_dollars, :currency, :check_number, :allocatable_sgid)
  end

  def locate_allocatable
    return nil unless params[:payment][:allocatable_sgid].present?
    GlobalID::Locator.locate_signed(params[:payment][:allocatable_sgid])
  end

  def build_payment_attributes(payment_params, allocatable)
    attrs = payment_params.except(:allocatable_sgid, :type)
    attrs[:person_id] ||= allocatable.try(:registrant_id) if allocatable.is_a?(EventRegistration)
    attrs
  end

  def process_allocation!(payment, allocatable)
    Payment.transaction do
      payment.save!

      payment.with_lock do
        allocation_amount = calculate_allocation_amount(payment, allocatable)
        current_allocated = payment.allocations.sum(:amount)

        if current_allocated + allocation_amount > payment.amount_cents
          raise ActiveRecord::Rollback, "Cannot allocate more than payment amount"
        end

        Allocation.create!(
          source: payment,
          allocatable: allocatable,
          amount: allocation_amount
        )

        payment.update!(amount_cents_remaining: payment.amount_cents - current_allocated - allocation_amount)
      end
    end
  end

  def calculate_allocation_amount(payment, allocatable)
    payment_amount = payment.amount_cents

    if allocatable.is_a?(EventRegistration)
      event_cost = allocatable.event.cost_cents
      already_allocated = allocatable.allocations_sum
      remaining_needed = event_cost - already_allocated

      if remaining_needed <= 0
        payment.errors.add(:base, "Event Registration is already fully paid.")
        raise ActiveRecord::RecordInvalid.new(payment)
      end

      [ payment_amount, remaining_needed ].min
    else
      payment_amount
    end
  end

  def redirect_path_for(allocatable)
    allocations_path(allocatable_sgid: allocatable.to_sgid.to_s)
  end
end
