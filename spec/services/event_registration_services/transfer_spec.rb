require "rails_helper"

RSpec.describe EventRegistrationServices::Transfer do
  let(:registrant) { create(:person) }
  let(:source_event) { create(:event, title: "Spring workshop") }
  let(:target_event) { create(:event, title: "Summer workshop") }
  let(:source) { create(:event_registration, event: source_event, registrant: registrant, status: "registered") }

  describe ".call" do
    it "creates a new registration on the target event linked to the source" do
      result = described_class.call(source: source, target_event_id: target_event.id)

      expect(result).to be_success
      new_registration = result.registration
      expect(new_registration.event).to eq(target_event)
      expect(new_registration.registrant).to eq(registrant)
      expect(new_registration.status).to eq("registered")
      expect(new_registration.transferred_from).to eq(source)
    end

    it "marks the source registration as transferred" do
      described_class.call(source: source, target_event_id: target_event.id)
      expect(source.reload.status).to eq("transferred")
    end

    it "leaves the source's payment/allocations untouched" do
      payment = create(:payment, person: registrant, amount_cents: 1000, amount_cents_remaining: nil)
      allocation = create(:allocation, source: payment, allocatable: source, amount: 1000)

      described_class.call(source: source, target_event_id: target_event.id)

      expect(allocation.reload.allocatable).to eq(source)
      expect(source.reload.allocations_sum).to eq(1000)
    end

    it "fails when no target event is chosen" do
      result = described_class.call(source: source, target_event_id: nil)
      expect(result).not_to be_success
      expect(result.error).to match(/choose an event/i)
    end

    it "fails when the target is the same as the source event" do
      result = described_class.call(source: source, target_event_id: source_event.id)
      expect(result).not_to be_success
      expect(result.error).to match(/different event/i)
    end

    it "fails when the registrant is already registered for the target event" do
      create(:event_registration, event: target_event, registrant: registrant)
      result = described_class.call(source: source, target_event_id: target_event.id)
      expect(result).not_to be_success
      expect(result.error).to match(/already registered/i)
    end

    it "does not mark the source transferred when creation fails" do
      create(:event_registration, event: target_event, registrant: registrant)
      described_class.call(source: source, target_event_id: target_event.id)
      expect(source.reload.status).to eq("registered")
    end
  end
end
