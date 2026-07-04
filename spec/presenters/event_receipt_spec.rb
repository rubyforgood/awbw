require "rails_helper"

RSpec.describe EventReceipt do
  describe ".from_registration" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let(:registrant) { create(:person, first_name: "Helena", last_name: "Lopez") }
    let(:registration) { create(:event_registration, event: event, registrant: registrant) }

    it "reconciles the event charge against its payments to a zero balance" do
      payment = create(:payment, type: "CashPayment", amount_cents: 150_000)
      create(:allocation, source: payment, allocatable: registration, amount: 150_000)

      receipt = described_class.from_registration(registration)

      expect(receipt.attention).to eq("Helena Lopez")
      expect(receipt.bill_to_name).to eq("Helena Lopez")
      expect(receipt.total_cents).to eq(150_000)
      expect(receipt.amount_paid_cents).to eq(150_000)
      expect(receipt.balance_cents).to eq(0)
      expect(receipt).to be_paid_in_full

      item = receipt.line_items.first
      expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
      expect(item.amount_cents).to eq(150_000)

      entry = receipt.entries.first
      expect(receipt.entries.size).to eq(1)
      expect(entry.method).to eq("Cash")
      expect(entry.amount_cents).to eq(150_000)
    end

    it "labels a check payment with its check number" do
      payment = create(:payment, type: "CheckPayment", amount_cents: 150_000, check_number: "4821")
      create(:allocation, source: payment, allocatable: registration, amount: 150_000)

      receipt = described_class.from_registration(registration)
      entry = receipt.entries.first

      expect(entry.method).to eq("Check")
      expect(entry.reference).to eq("Check #4821")
    end

    it "lists multiple allocations as separate ledger entries in order" do
      cash = create(:payment, type: "CashPayment", amount_cents: 50_000)
      check = create(:payment, type: "CheckPayment", amount_cents: 100_000, check_number: "12")
      create(:allocation, source: cash, allocatable: registration, amount: 50_000)
      create(:allocation, source: check, allocatable: registration, amount: 100_000)

      receipt = described_class.from_registration(registration)

      expect(receipt.entries.map(&:method)).to eq([ "Cash", "Check" ])
      expect(receipt.entries.map(&:amount_cents)).to eq([ 50_000, 100_000 ])
      expect(receipt.amount_paid_cents).to eq(150_000)
      expect(receipt.balance_cents).to eq(0)
    end

    context "with a snapshotted organization" do
      let(:organization) { create(:organization, name: "A Greater Hope") }

      before do
        create(:event_registration_organization, event_registration: registration, organization: organization)
        create(:address, addressable: organization, street_address: "PO Box 1477", city: "Victorville", state: "CA", zip_code: "92393")
        payment = create(:payment, type: "CashPayment", amount_cents: 150_000)
        create(:allocation, source: payment, allocatable: registration, amount: 150_000)
      end

      it "addresses the receipt to the organization but keeps the registrant as attention" do
        receipt = described_class.from_registration(registration)

        expect(receipt.bill_to_name).to eq("A Greater Hope")
        expect(receipt.attention).to eq("Helena Lopez")
        expect(receipt.bill_to_address_lines).to eq([ "PO Box 1477", "Victorville, CA 92393" ])
        expect(receipt.client_id).to eq(organization.id)
      end
    end
  end
end
