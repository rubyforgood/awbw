require "rails_helper"

RSpec.describe "Refunds", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "POST /refunds" do
    it "names the refundable amount in dollars when the refund is too large" do
      payment = CashPayment.create!(person:, amount_cents: 1_212, amount_cents_remaining: 12)

      expect {
        post refunds_path, params: {
          refund: { refundable_id: payment.id, refundable_type: "Payment", recipient_type: "Person",
                    recipient_id: person.id, method: "cash", amount_dollars: "9.00" }
        }
      }.not_to change(Refund, :count)

      expect(flash[:error]).to include("$0.12 not yet allocated")
    end
  end

  describe "GET /refunds/new" do
    it "tells the admin how much can be refunded" do
      payment = CashPayment.create!(person:, amount_cents: 1_212, amount_cents_remaining: 12)

      get new_refund_path(payment_sgid: payment.to_sgid.to_s)

      expect(response.body).to include("Up to $0.12")
    end
  end
end
