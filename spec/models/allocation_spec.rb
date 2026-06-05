require "rails_helper"

RSpec.describe Allocation, type: :model do
  describe "validations" do
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

      it "skips validation when allocatable is not an EventRegistration" do
        allocation = build(:allocation, source: payment, allocatable: registration, amount: 5_000)
        allow(allocation).to receive(:allocatable).and_return(nil)
        allocation.send(:validate_event_registration_cost)
        expect(allocation.errors[:base]).to be_empty
      end
    end
  end
end
