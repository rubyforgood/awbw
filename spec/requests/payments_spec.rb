require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:admin)        { create(:user, :with_person, super_user: true) }
  let(:regular_user) { create(:user, :with_person) }

  let(:event)              { create(:event, title: "Test Event") }
  let(:event_registration) { create(:event_registration, event: event, registrant: admin.person) }
  let!(:payment) do
    create(:payment, payer: admin.person).tap do |p|
      event_registration.update!(payment: p)
    end
  end

  # ============================================================
  # ADMIN
  # ============================================================
  context "as an admin" do
    before { sign_in admin }

    describe "GET /payments" do
      it "can access index" do
        get payments_path
        expect(response).to have_http_status(:success)
      end

      it "paginates results" do
        create_list(:payment, 3)
        get payments_path, params: { number_of_items_per_page: 1 }
        expect(response).to have_http_status(:success)
      end

      it "filters by status" do
        get payments_path, params: { status: "succeeded" }
        expect(response).to have_http_status(:success)
      end

      it "filters by payer_id" do
        other_person = create(:person)
        other_payment = create(:payment, payer: other_person, amount_cents: 9999)
        get payments_path, params: { payer_id: other_person.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(other_payment.decorate.formatted_amount)
        expect(response.body).not_to include(payment.decorate.formatted_amount)
      end

      it "filters by organization_id" do
        org = create(:organization)
        org_payment = create(:payment, organization: org, amount_cents: 7777)
        get payments_path, params: { organization_id: org.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(org_payment.decorate.formatted_amount)
        expect(response.body).not_to include(payment.decorate.formatted_amount)
      end

      it "filters by event_id" do
        get payments_path, params: { event_id: event.id }
        expect(response).to have_http_status(:success)
        expect(response.body).to include(payment.decorate.formatted_amount)
      end
    end

    describe "GET /payments/:id" do
      it "can view payment" do
        get payment_path(payment)
        expect(response).to have_http_status(:success)
      end
    end

    describe "GET /payments/new" do
      it "can access new form" do
        get new_payment_path
        expect(response).to have_http_status(:success)
      end
    end

    describe "GET /payments/:id/edit" do
      it "can access edit form" do
        get edit_payment_path(payment)
        expect(response).to have_http_status(:success)
      end
    end

    describe "POST /payments" do
      it "can create a payment" do
        expect {
          post payments_path, params: {
            payment: {
              amount_cents: 2000,
              currency: "usd",
              status: "succeeded",
              payment_type: "stripe",
              stripe_payment_intent_id: "pi_test_#{SecureRandom.hex(8)}",
              payer_id: admin.person.id
            }
          }
        }.to change(Payment, :count).by(1)
      end
    end

    describe "PATCH /payments/:id" do
      it "can update a payment" do
        patch payment_path(payment), params: { payment: { status: "refunded" } }
        expect(payment.reload.status).to eq("refunded")
      end
    end

    describe "DELETE /payments/:id" do
      it "can delete a payment" do
        expect {
          delete payment_path(payment)
        }.to change(Payment, :count).by(-1)
      end
    end
  end

  # ============================================================
  # REGULAR USER
  # ============================================================
  context "as a regular user" do
    before { sign_in regular_user }

    describe "GET /payments" do
      it "redirects to root" do
        get payments_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "GET /payments/:id" do
      it "redirects to root" do
        get payment_path(payment)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /payments" do
      it "does not create a payment" do
        expect {
          post payments_path, params: {
            payment: {
              amount_cents: 2000,
              payer_id: regular_user.person.id
            }
          }
        }.not_to change(Payment, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /payments/:id" do
      it "redirects to root" do
        patch payment_path(payment), params: { payment: { status: "refunded" } }
        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /payments/:id" do
      it "does not delete the payment" do
        expect {
          delete payment_path(payment)
        }.not_to change(Payment, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ============================================================
  # GUEST
  # ============================================================
  context "as a guest" do
    describe "GET /payments" do
      it "redirects to root" do
        get payments_path
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /payments" do
      it "does not create a payment" do
        expect {
          post payments_path, params: {
            payment: {
              amount_cents: 2000,
              payer_id: admin.person.id
            }
          }
        }.not_to change(Payment, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "PATCH /payments/:id" do
      it "redirects to root" do
        patch payment_path(payment), params: { payment: { status: "refunded" } }
        expect(response).to redirect_to(root_path)
      end
    end

    describe "DELETE /payments/:id" do
      it "does not delete the payment" do
        expect {
          delete payment_path(payment)
        }.not_to change(Payment, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
