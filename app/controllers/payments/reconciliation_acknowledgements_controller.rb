module Payments
  class ReconciliationAcknowledgementsController < ApplicationController
    before_action :set_payment

    def create
      authorize! @payment
      @payment.update!(reconciliation_acknowledged_at: Time.current)
      redirect_to payment_path(@payment), notice: "Credit acknowledged.", status: :see_other
    end

    def destroy
      authorize! @payment
      @payment.update!(reconciliation_acknowledged_at: nil)
      redirect_to payment_path(@payment), notice: "Acknowledgement removed.", status: :see_other
    end

    private

    def set_payment = @payment = Payment.find(params[:payment_id])
  end
end
