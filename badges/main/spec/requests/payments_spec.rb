require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "POST /payments" do
    context "when allocating to a fully-paid EventRegistration" do
      let(:event) { create(:event, cost_cents: 10_000) }
      let(:registration) { create(:event_registration, event:) }

      before do
        initial_payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000, person:)
        create(:allocation, source: initial_payment, allocatable: registration, amount: 10_000)
      end

      it "does not create a payment or allocation" do
        expect {
          post payments_path, params: {
            payment: {
              type: "CashPayment",
              payer_type: "Person",
              person_id: person.id,
              amount_dollars: "11.11",
              allocatable_sgid: registration.to_sgid.to_s
            }
          }
        }.to change(Payment, :count).by(0)
          .and change(Allocation, :count).by(0)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "when allocating to a free EventRegistration" do
      let(:free_event) { create(:event, cost_cents: nil) }
      let(:registration) { create(:event_registration, event: free_event) }

      it "does not create a payment or allocation" do
        expect {
          post payments_path, params: {
            payment: {
              type: "CashPayment",
              payer_type: "Person",
              person_id: person.id,
              amount_dollars: "5.00",
              allocatable_sgid: registration.to_sgid.to_s
            }
          }
        }.to change(Payment, :count).by(0)
          .and change(Allocation, :count).by(0)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
