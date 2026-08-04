require "rails_helper"

RSpec.describe Allocation, type: :model do
  describe "validations" do
    describe "validate_ce_registration_cost" do
      let(:ce_reg) { create(:continuing_education_registration, cost_cents: 10_000) }
      let(:payment) { create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000) }

      it "is valid when amount is within the CE cost" do
        allocation = build(:allocation, source: payment, allocatable: ce_reg, amount: 5_000)
        expect(allocation).to be_valid
      end

      it "is invalid when allocating more than the remaining CE cost" do
        create(:allocation, source: payment, allocatable: ce_reg, amount: 8_000)
        second_payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        allocation = build(:allocation, source: second_payment, allocatable: ce_reg, amount: 5_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base].join).to include("Cannot allocate more than remaining CE cost")
      end

      it "is invalid when the CE registration is already fully paid" do
        create(:allocation, source: payment, allocatable: ce_reg, amount: 10_000)
        second_payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        allocation = build(:allocation, source: second_payment, allocatable: ce_reg, amount: 1_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("CE registration is already fully paid.")
      end
    end

    describe "dues registrations" do
      let(:term) { create(:dues_registration, cost_cents: 2_500) }
      let(:payment) { create(:payment, amount_cents: 2_500, amount_cents_remaining: 2_500) }

      it "is valid when amount is within the dues cost" do
        expect(build(:allocation, source: payment, allocatable: term, amount: 1_000)).to be_valid
      end

      it "is invalid when allocating more than the remaining dues" do
        create(:allocation, source: payment, allocatable: term, amount: 2_000)
        allocation = build(:allocation,
          source: create(:payment, amount_cents: 2_000, amount_cents_remaining: 2_000),
          allocatable: term, amount: 2_000)

        expect(allocation).not_to be_valid
        expect(allocation.errors[:base].join).to include("Cannot allocate more than the remaining dues")
      end

      it "is invalid when the dues year is already fully paid" do
        create(:allocation, source: payment, allocatable: term, amount: 2_500)
        allocation = build(:allocation,
          source: create(:payment, amount_cents: 500, amount_cents_remaining: 500),
          allocatable: term, amount: 500)

        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("Dues year is already fully paid.")
      end

      it "is invalid when the dues year is comped" do
        allocation = build(:allocation, source: payment, allocatable: create(:dues_registration, :comped), amount: 500)

        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("Cannot allocate to a dues year with no cost.")
      end

      it "allows a reversal on a fully paid dues year" do
        create(:allocation, source: payment, allocatable: term, amount: 2_500)
        expect(build(:allocation, source: payment, allocatable: term, amount: -2_500)).to be_valid
      end
    end

    describe "validate_event_registration_cost" do
      let(:event) { create(:event, cost_cents: 10_000) }
      let(:registration) { create(:event_registration, event:) }
      let(:payment) { create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000) }

      it "is valid when amount is within remaining cost" do
        allocation = build(:allocation, source: payment, allocatable: registration, amount: 5_000)
        expect(allocation).to be_valid
      end

      it "is valid when amount exactly covers remaining cost" do
        allocation = build(:allocation, source: payment, allocatable: registration, amount: 10_000)
        expect(allocation).to be_valid
      end

      it "is invalid when allocating to a zero-cost event" do
        free_reg = create(:event_registration, event: create(:event, cost_cents: 0))
        allocation = build(:allocation, source: payment, allocatable: free_reg, amount: 5_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("Cannot allocate to a free event.")
      end

      it "is invalid when allocating to a free event" do
        free_event = create(:event, cost_cents: nil)
        free_reg = create(:event_registration, event: free_event)
        allocation = build(:allocation, source: payment, allocatable: free_reg, amount: 5_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("Cannot allocate to a free event.")
      end

      it "is invalid when a positive amount is allocated to a fully paid registration" do
        create(:allocation, source: payment, allocatable: registration, amount: 10_000)
        second_payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        allocation = build(:allocation, source: second_payment, allocatable: registration, amount: 1_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include("Event registration is already fully paid.")
      end

      it "allows a reversal (negative amount) on a fully paid registration" do
        create(:allocation, source: payment, allocatable: registration, amount: 10_000)
        allocation = build(:allocation, source: payment, allocatable: registration, amount: -10_000)
        expect(allocation).to be_valid
      end

      it "allows a zero allocation on a fully paid registration" do
        create(:allocation, source: payment, allocatable: registration, amount: 10_000)
        allocation = build(:allocation, source: payment, allocatable: registration, amount: 0)
        expect(allocation).to be_valid
      end

      it "is invalid when amount exceeds remaining cost" do
        create(:allocation, source: payment, allocatable: registration, amount: 8_000)
        second_payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        allocation = build(:allocation, source: second_payment, allocatable: registration, amount: 5_000)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include(a_string_starting_with("Cannot allocate more than remaining"))
      end

      it "allows increasing an existing allocation when there is room" do
        allocation = create(:allocation, source: payment, allocatable: registration, amount: 3_000)
        allocation.amount = 7_000
        expect(allocation).to be_valid
      end

      it "blocks increasing an existing allocation beyond the event cost" do
        allocation = create(:allocation, source: payment, allocatable: registration, amount: 3_000)
        allocation.amount = 15_000
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base]).to include(a_string_starting_with("Cannot allocate more than remaining"))
      end

      it "does not run the event-cost validation for a non-EventRegistration allocatable" do
        ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
        allocation = build(:allocation, source: payment, allocatable: ce_reg, amount: 5_000)
        expect(allocation).to be_valid
        expect(allocation.errors[:base]).to be_empty
      end
    end
  end
end
