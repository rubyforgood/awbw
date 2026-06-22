require "rails_helper"

RSpec.describe "Allocations", type: :request do
  let(:admin)     { create(:user, :admin) }
  let(:event)     { create(:event, cost_cents: 10_000) }
  let(:reg)       { create(:event_registration, event:) }

  before { sign_in admin }

  describe "GET /allocations" do
    it "renders the searchable list of all allocations" do
      get allocations_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("All allocations")
    end

    it "renders the focused view scoped to a single registration" do
      get allocations_path(allocatable_sgid: reg.to_sgid.to_s)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Allocations")
      expect(response.body).to include("Add cash payment")
      expect(response.body).to include(reg.registrant.full_name)
    end

    it "renders the results turbo frame" do
      get allocations_path, headers: { "Turbo-Frame" => "allocation_results" }

      expect(response).to have_http_status(:success)
    end

    it "links the back link to the registrants roster when return_to=registrants" do
      get allocations_path(allocatable_sgid: reg.to_sgid.to_s, return_to: "registrants")

      expect(response.body).to include("href=\"#{registrants_event_path(event)}\"")
    end

    it "links the back link to bulk payments, re-expanding the submission row, when return_to=bulk_payments" do
      get allocations_path(allocatable_sgid: reg.to_sgid.to_s, return_to: "bulk_payments", expand: "42")

      expect(response.body).to include("href=\"#{bulk_payments_event_path(event, expand: "42", anchor: "payment-card-42")}\"")
    end

    it "links the back link to the registration by default" do
      get allocations_path(allocatable_sgid: reg.to_sgid.to_s)

      expect(response.body).to include("href=\"#{edit_event_registration_path(reg)}\"")
    end
  end

  describe "POST /allocations" do
    context "with a Scholarship source" do
      let(:scholarship) { create(:scholarship) }

      it "creates an allocation and redirects to scholarship" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Scholarship",
              source_id: scholarship.id,
              allocatable_type: "EventRegistration",
              allocatable_id: reg.id,
              amount_dollars: "10.00"
            }
          }
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(scholarship_path(scholarship))
        expect(Allocation.last.source).to eq(scholarship)
        expect(Allocation.last.amount).to eq(1000)
      end
    end

    context "with a Refund source" do
      let(:payment) { create(:payment, amount_cents: 5000, amount_cents_remaining: 5000) }
      let(:refund)  { create(:refund, refundable: payment, recipient: create(:person), amount_cents: 1000, method: "check") }

      it "creates an allocation and redirects to refund" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Refund",
              source_id: refund.id,
              allocatable_type: "EventRegistration",
              allocatable_id: reg.id,
              amount_dollars: "5.00"
            }
          }
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(refund_path(refund))
        expect(Allocation.last.source).to eq(refund)
      end
    end

    context "with a Discount source" do
      let(:discount) { create(:discount) }

      it "creates an allocation and redirects to discount" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Discount",
              source_id: discount.id,
              allocatable_type: "EventRegistration",
              allocatable_id: reg.id,
              amount_dollars: "10.00"
            }
          }
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(discount_path(discount))
        expect(Allocation.last.source).to eq(discount)
      end
    end

    context "with an EventRegistration that is a free event" do
      let(:scholarship) { create(:scholarship) }
      let(:free_event)  { create(:event, cost_cents: nil) }
      let(:free_reg)    { create(:event_registration, event: free_event) }

      it "does not create an allocation" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Scholarship",
              source_id: scholarship.id,
              allocatable_type: "EventRegistration",
              allocatable_id: free_reg.id,
              amount_dollars: "10.00"
            }
          }
        }.not_to change(Allocation, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with an EventRegistration that is fully paid" do
      let(:scholarship) { create(:scholarship) }

      before do
        create(:allocation, source: create(:payment, amount_cents: event.cost_cents, amount_cents_remaining: event.cost_cents), allocatable: reg, amount: event.cost_cents)
      end

      it "does not create an allocation" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Scholarship",
              source_id: scholarship.id,
              allocatable_type: "EventRegistration",
              allocatable_id: reg.id,
              amount_dollars: "5.00"
            }
          }
        }.not_to change(Allocation, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with an EventRegistration exceeding remaining cost" do
      let(:scholarship) { create(:scholarship) }

      before do
        create(:allocation, source: create(:payment, amount_cents: event.cost_cents, amount_cents_remaining: event.cost_cents), allocatable: reg, amount: 7_000)
      end

      it "does not create an allocation" do
        expect {
          post allocations_path, params: {
            allocation: {
              source_type: "Scholarship",
              source_id: scholarship.id,
              allocatable_type: "EventRegistration",
              allocatable_id: reg.id,
              amount_dollars: "35.00"
            }
          }
        }.not_to change(Allocation, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "POST /allocations/:id/revert" do
    context "with a Scholarship source" do
      let(:scholarship) { create(:scholarship) }
      let!(:allocation) { create(:allocation, source: scholarship, allocatable: reg, amount: 1000) }

      it "reverts the allocation and redirects to scholarship" do
        expect {
          post revert_allocation_path(allocation)
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(scholarship_path(scholarship))
        expect(allocation.reload.reverted?).to be true
        expect(Allocation.last.amount).to eq(-1000)
      end
    end

    context "with a Refund source" do
      let(:payment)   { create(:payment, amount_cents: 5000, amount_cents_remaining: 5000) }
      let(:refund)    { create(:refund, refundable: payment, recipient: create(:person), amount_cents: 1000, method: "check") }
      let!(:allocation) { create(:allocation, source: refund, allocatable: reg, amount: 500) }

      it "reverts the allocation and redirects to refund" do
        expect {
          post revert_allocation_path(allocation)
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(refund_path(refund))
        expect(allocation.reload.reverted?).to be true
      end
    end

    context "with a Discount source" do
      let(:discount)   { create(:discount) }
      let!(:allocation) { create(:allocation, source: discount, allocatable: reg, amount: 1000) }

      it "reverts the allocation and redirects to discount" do
        expect {
          post revert_allocation_path(allocation)
        }.to change(Allocation, :count).by(1)

        expect(response).to redirect_to(discount_path(discount))
        expect(allocation.reload.reverted?).to be true
      end
    end
  end
end
