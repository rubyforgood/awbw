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

    context "when recording a check payment with a memo" do
      let(:event) { create(:event, cost_cents: 10_000) }
      let(:registration) { create(:event_registration, event:) }

      it "stores the check number and memo" do
        post payments_path, params: {
          payment: {
            type: "CheckPayment",
            payer_type: "Person",
            person_id: person.id,
            amount_dollars: "50.00",
            check_number: "1234",
            memo: "Spring workshop",
            allocatable_sgid: registration.to_sgid.to_s
          }
        }

        payment = Payment.last
        expect(payment.check_number).to eq("1234")
        expect(payment.memo).to eq("Spring workshop")
      end
    end
  end

  describe "POST /payments for a ContinuingEducationRegistration" do
    let(:ce) { create(:continuing_education_registration, cost_cents: 5_000) }

    before { sign_in admin }

    it "records the payment against the CE registration's registrant" do
      expect {
        post payments_path, params: {
          payment: {
            type: "CashPayment",
            payer_type: "Person",
            amount_dollars: "50.00",
            allocatable_sgid: ce.to_sgid.to_s
          }
        }
      }.to change(Payment, :count).by(1)
        .and change(Allocation, :count).by(1)

      expect(Payment.last.person).to eq(ce.event_registration.registrant)
      expect(ce.reload).to be_paid_in_full
    end
  end

  describe "POST /payments/allocation_form" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }

    it "renders compound payer and additional designation pickers" do
      post allocation_form_payments_path,
        params: { type: "CashPayment", allocatable_sgid: registration.to_sgid.to_s },
        as: :turbo_stream

      expect(response.body).to include("Whose account is the money coming from?")
      expect(response.body).to include("payment[payer_sgid]")
      expect(response.body).to include("payment[additional_designation_sgid]")
      expect(response.body).to include("Additional designation")
    end

    it "preselects the registrant in a compound picker" do
      post allocation_form_payments_path,
        params: { type: "CashPayment", allocatable_sgid: registration.to_sgid.to_s },
        as: :turbo_stream

      expect(response.body).to match(%r{<option[^>]*selected[^>]*>#{Regexp.escape(registration.registrant.full_name)}[^<]*Person</option>})
    end
  end

  describe "PATCH /payments/:id" do
    let(:organization) { create(:organization) }

    it "updates payer and designation via sgids" do
      payment = create(:payment, person:, organization: nil)

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: person.to_sgid.to_s
        }
      }

      payment.reload
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(person)
    end

    it "switches the payer from a person to an organization" do
      payment = create(:payment, person:, organization: nil)

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: ""
        }
      }

      payment.reload
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to be_nil
    end

    it "clears the additional designation when blank is sent" do
      payment = create(:payment, person:, organization:, payer_type: "Organization")

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: ""
        }
      }

      payment.reload
      expect(payment.organization).to eq(organization)
      expect(payment.person).to be_nil
    end

    it "shows a flash alert when validation fails" do
      payment = create(:payment, person:, organization: nil)
      other_person = create(:person)

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: person.to_sgid.to_s,
          additional_designation_sgid: other_person.to_sgid.to_s
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to include("must be different kinds")
    end
  end

  describe "payer type on create" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }
    let(:organization) { create(:organization) }

    it "keeps Organization as the payer when both a person and an organization are given" do
      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_type: "Organization",
          person_id: registration.registrant_id,
          organization_id: organization.id,
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      expect(Payment.last.payer_type).to eq("Organization")
      expect(Payment.last.organization).to eq(organization)
    end

    it "switches the payer type to Person when only a person is selected" do
      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_type: "Organization",
          person_id: registration.registrant_id,
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      expect(Payment.last.payer_type).to eq("Person")
    end
  end

  describe "payer/additional designation via sgids" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }
    let(:organization) { create(:organization) }

    it "creates a payment from an organization payer and a person designation" do
      post payments_path, params: {
        payment: {
          type: "CheckPayment",
          check_number: "1234",
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: registration.registrant.to_sgid.to_s,
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(registration.registrant)
    end

    it "rejects two people without creating a payment" do
      other_person = create(:person)

      expect {
        post payments_path, params: {
          payment: {
            type: "CashPayment",
            payer_sgid: registration.registrant.to_sgid.to_s,
            additional_designation_sgid: other_person.to_sgid.to_s,
            amount_dollars: "50.00",
            allocatable_sgid: registration.to_sgid.to_s
          }
        }
      }.to change(Payment, :count).by(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be different kinds")
    end

    it "creates a payment from a person payer with no additional designation" do
      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_sgid: registration.registrant.to_sgid.to_s,
          additional_designation_sgid: "",
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Person")
      expect(payment.person).to eq(registration.registrant)
      expect(payment.organization).to be_nil
    end

    it "creates a standalone payment from sgids without an allocatable" do
      organization = create(:organization)

      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: registration.registrant.to_sgid.to_s,
          amount_dollars: "25.00"
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(registration.registrant)
      expect(payment.allocations).to be_empty
    end
  end
end
