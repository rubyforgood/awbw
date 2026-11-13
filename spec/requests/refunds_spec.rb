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
          refund: { refundable_id: payment.id, refundable_type: "Payment", recipient_sgid: person.to_sgid.to_s,
                    method: "cash", amount_dollars: "9.00" }
        }
      }.not_to change(Refund, :count)

      expect(flash[:error]).to include("$0.12 not yet allocated")
    end
  end

  describe "POST /refunds recipient" do
    it "infers the recipient's type from the picked person or organization" do
      organization = create(:organization)
      payment = CashPayment.create!(person:, amount_cents: 5_000)

      post refunds_path, params: {
        refund: { refundable_id: payment.id, refundable_type: "Payment", recipient_sgid: organization.to_sgid.to_s,
                  method: "cash", amount_dollars: "10.00" }
      }

      expect(Refund.last.recipient).to eq(organization)
    end
  end

  describe "GET /refunds/new" do
    it "tells the admin how much can be refunded" do
      payment = CashPayment.create!(person:, amount_cents: 1_212, amount_cents_remaining: 12)

      get new_refund_path(payment_sgid: payment.to_sgid.to_s)

      expect(response.body).to include("Up to $0.12")
    end

    it "prefills the payer as the recipient" do
      organization = create(:organization, name: "Sample Unified District")
      payment = CheckPayment.create!(organization:, payer_type: "Organization", amount_cents: 5_000, check_number: "1")

      get new_refund_path(payment_sgid: payment.to_sgid.to_s)

      selected = Nokogiri::HTML(response.body).at_css("select#refund_recipient_sgid option[selected]")
      expect(selected.text).to eq("Sample Unified District · Organization")
      expect(GlobalID::Locator.locate_signed(selected["value"])).to eq(organization)
    end
  end
end
