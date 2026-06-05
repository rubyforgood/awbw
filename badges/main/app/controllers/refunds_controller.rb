class RefundsController < ApplicationController
  before_action :authenticate_user!

  def show
    @refund = Refund.find(params[:id])
    authorize! @refund
  end

  def new
    authorize!
    if params[:payment_sgid].present?
      @payment = GlobalID::Locator.locate_signed(params[:payment_sgid])
    end
    @refund = Refund.new(
      refundable: @payment,
      refundable_type: "Payment",
      refundable_id: @payment&.id
    )
  end

  def create
    authorize!

    @payment = Payment.find_by(id: params[:refund][:refundable_id])

    amount_val = (params[:refund][:amount_dollars].to_d * 100).to_i if params[:refund][:amount_dollars].present?

    if @payment.is_a?(ExternalProcessorPayment) && @payment.pay_charge.present?
      @payment.with_lock do
        if amount_val > @payment.amount_cents_remaining
          flash[:error] = "Refund cannot exceed remaining amount (#{@payment.amount_cents_remaining})"
          redirect_to new_refund_path(payment_sgid: @payment.to_sgid.to_s) and return
        end

        @payment.pay_charge.refund!(amount_val)
        @payment.pay_charge.sync!
      end
      redirect_to payment_path(@payment), notice: "Refund processed via Stripe"
    else
      @refund = Refund.new(
        refundable: @payment,
        recipient_type: params[:refund][:recipient_type],
        recipient_id: params[:refund][:recipient_id],
        amount_cents: amount_val,
        method: params[:refund][:method]
      )

      @payment.with_lock do
        remaining = @payment.amount_cents_remaining

        if amount_val > remaining
          flash[:error] = "Refund cannot exceed remaining amount (#{remaining})"
          redirect_to new_refund_path(payment_sgid: @payment.to_sgid.to_s)
          return
        end

        if @refund.save
          redirect_to payment_path(@payment), notice: "Refund created"
        else
          flash[:error] = @refund.errors.full_messages.join(", ")
          render :new, status: :unprocessable_content
        end
      end
    end
  end
end
