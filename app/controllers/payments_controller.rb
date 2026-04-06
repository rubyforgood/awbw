class PaymentsController < ApplicationController
  def index
    authorize!
    per_page = params[:number_of_items_per_page].presence || 10
    @payments = Payment.order(created_at: :desc).paginate(page: params[:page], per_page: per_page)
  end

  def new
    authorize!
    payment_type = params[:type]
    @payment = payment_type.safe_constantize.new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      if @allocatable.is_a?(EventRegistration)
        @payment.payer = @allocatable.registrant
      end
    end
  end

  def create
    authorize!
    payment_class = params[:payment][:type].presence&.safe_constantize || CashPayment

    allocatable = nil
    if params[:payment][:allocatable_sgid].present?
      allocatable = GlobalID::Locator.locate_signed(params[:payment][:allocatable_sgid])
    end

    payment_attrs = payment_params.except(:allocatable_sgid)
    payment_attrs[:payer_type] = params[:payment][:payer_type].presence || "Person"
    payment_attrs[:payer_id] = params[:payment][:payer_id].presence || (allocatable.try(:registrant_id) if allocatable.is_a?(EventRegistration))

    @payment = payment_class.new(payment_attrs)

    if @payment.save
      if allocatable.present?
        Allocation.transaction do
          @payment.with_lock do
            new_allocation_amount = @payment.amount_cents
            current_allocated = @payment.allocations.sum(:amount)

            if current_allocated + new_allocation_amount > @payment.amount_cents
              raise ActiveRecord::Rollback, "Cannot allocate more than payment amount"
            end

            Allocation.create!(
              source: @payment,
              allocatable: allocatable,
              amount: @payment.amount_cents
            )
          end
        end
      end

      respond_to do |format|
        format.turbo_stream { redirect_to payments_path }
        format.html { redirect_to payments_path, notice: "Payment was successfully created." }
      end
    else
      @allocatable = allocatable
      render :new, status: :unprocessable_content
    end
  end

  def show
    @payment = Payment.find(params[:id])
    authorize! @payment, with: PaymentPolicy
  end

  def allocation_form
    authorize!
    payment_type = params[:type].presence || "CashPayment"
    @payment = payment_type.safe_constantize.new

    if params[:allocatable_sgid].present?
      @allocatable = GlobalID::Locator.locate_signed(params[:allocatable_sgid])
      if @allocatable.is_a?(EventRegistration)
        @payment.payer = @allocatable.registrant
      end
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

  def payment_params
    params.require(:payment).permit(:type, :payer_type, :payer_id, :amount_dollars, :currency, :check_number, :allocatable_sgid)
  end
end
