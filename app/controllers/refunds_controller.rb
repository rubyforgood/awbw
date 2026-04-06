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

    remaining = @payment.unallocated_amount_cents

    if amount_val > remaining
      flash[:error] = "Refund cannot exceed unallocated amount (#{remaining})"
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
        @payment.update!(allocated_amount_cents: @payment.allocated_amount_cents + amount_val)
      end
      redirect_to payment_path(@payment), notice: "Refund created"
    else
      render :new, status: :unprocessable_content
    end
  end
end
