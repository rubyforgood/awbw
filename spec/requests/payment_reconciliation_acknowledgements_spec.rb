require "rails_helper"

RSpec.describe "Payment reconciliation acknowledgements", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let(:payment) do
    create(:external_processor_payment, person:, amount_cents: 1_000, amount_cents_remaining: 1_000)
  end

  before { sign_in admin }

  it "acknowledges and removes the acknowledgement" do
    post payment_reconciliation_acknowledgement_path(payment)

    expect(response).to redirect_to(payment_path(payment))
    expect(payment.reload.reconciliation_acknowledged_at).to be_present
    expect(flash[:notice]).to match(/acknowledged/i)

    delete payment_reconciliation_acknowledgement_path(payment)

    expect(payment.reload.reconciliation_acknowledged_at).to be_nil
    expect(flash[:notice]).to match(/removed/i)
  end

  it "shows the acknowledgement action and tooltip on the payment page" do
    get payment_path(payment)

    expect(response.body).to include("Acknowledge credit")
    expect(response.body).to include("Hides this credit from Data Health")
  end

  it "denies a non-admin" do
    sign_out admin
    sign_in create(:user, :with_person)

    post payment_reconciliation_acknowledgement_path(payment)

    expect(response).to redirect_to(root_path)
    expect(payment.reload.reconciliation_acknowledged_at).to be_nil
  end
end
