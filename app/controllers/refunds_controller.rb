class RefundsController < ApplicationController
  before_action :authenticate_user!

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

    remaining = @payment.amount_cents_remaining

    if amount_val > remaining
      flash[:error] = "Refund cannot exceed remaining amount (#{remaining})"
      redirect_to new_refund_path(payment_sgid: @payment.to_sgid.to_s)
      return
    end

    @refund = Refund.new(
      refundable: @payment,
      recipient_type: params[:refund][:recipient_type],
      recipient_id: params[:refund][:recipient_id],
      amount_cents: amount_val,
      method: params[:refund][:method]
    )

    if @refund.save
      @payment.with_lock do
        @payment.update!(amount_cents_remaining: @payment.amount_cents_remaining - amount_val)
      end
      redirect_to payment_path(@payment), notice: "Refund created"
    else
      flash[:error] = @refund.errors.full_messages.join(", ")
      render :new, status: :unprocessable_content
    end
  end
end
