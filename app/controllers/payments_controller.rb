class PaymentsController < ApplicationController
  def index
    authorize!
    @payments = Payment.all
  end

  def new
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
      format.html
      format.turbo_stream
    end
  end

  def create
    authorize!
    payment_class = params[:payment][:type].safe_constantize || CashPayment

    allocatable = nil
    if params[:payment][:allocatable_sgid].present?
      allocatable = GlobalID::Locator.locate_signed(params[:payment][:allocatable_sgid])
    end

    payment_attrs = payment_params.except(:allocatable_sgid)
    payment_attrs[:payer_type] = "Person"
    payment_attrs[:payer_id] = params[:payment][:payer_id].presence || (allocatable.try(:registrant_id) if allocatable.is_a?(EventRegistration))

    @payment = payment_class.new(payment_attrs)

    if @payment.save
      if allocatable.present?
        Allocation.create!(
          source: @payment,
          allocatable: allocatable,
          amount: @payment.amount_cents
        )
      end

      respond_to do |format|
        format.turbo_stream { redirect_to allocations_path(allocatable_sgid: params[:payment][:allocatable_sgid]) }
        format.html { redirect_to @payment, notice: "Payment was successfully created." }
      end
    else
      @allocatable = allocatable
      render :new, status: :unprocessable_content
    end
  end

  def show
    @payment = Payment.find(params[:id])
    authorize! @payment
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

    render turbo_stream: turbo_stream.append("payment-form", partial: "payments/form")
  end

  private

  def payment_params
    params.require(:payment).permit(:type, :payer_id, :amount_cents, :currency, :check_number, :allocatable_sgid)
  end
end
