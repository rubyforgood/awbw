require "rails_helper"

RSpec.describe EventInvoice do
  describe ".from_registration" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let(:registrant) { create(:person, first_name: "Helena", last_name: "Lopez") }
    let(:registration) { create(:event_registration, event: event, registrant: registrant) }

    it "bills the registrant for one attendee at the event cost" do
      invoice = described_class.from_registration(registration)

      expect(invoice.event).to eq(event)
      expect(invoice.attention).to eq("Helena Lopez")
      expect(invoice.bill_to_name).to eq("Helena Lopez")
      expect(invoice.line_items.size).to eq(1)

      item = invoice.line_items.first
      expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
      expect(item.quantity).to eq(1)
      expect(item.unit_price_cents).to eq(150_000)
      expect(item.amount_cents).to eq(150_000)
      expect(invoice.total_cents).to eq(150_000)
    end

    it "carries no applied credits and a full balance due when nothing is paid" do
      invoice = described_class.from_registration(registration)

      expect(invoice.entries).to be_empty
      expect(invoice.amount_applied_cents).to eq(0)
      expect(invoice.balance_due_cents).to eq(150_000)
    end

    it "reduces the balance due by the payments, scholarships, and discounts applied" do
      payment = create(:payment, type: "CashPayment", amount_cents: 40_000)
      scholarship = create(:scholarship, recipient: registrant, amount_cents: 50_000)
      discount = create(:discount, amount_cents: 10_000)
      create(:allocation, source: payment, allocatable: registration, amount: 40_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 50_000)
      create(:allocation, source: discount, allocatable: registration, amount: 10_000)

      invoice = described_class.from_registration(registration)

      expect(invoice.amount_applied_cents).to eq(100_000)
      expect(invoice.balance_due_cents).to eq(50_000)  # 150,000 charged − 100,000 applied
      expect(invoice.total_cents).to eq(150_000)       # the charge itself is unchanged
    end

    it "itemizes each payment by method, in order, with the check number as a reference" do
      cash = create(:payment, type: "CashPayment", amount_cents: 30_000)
      check = create(:payment, type: "CheckPayment", amount_cents: 20_000, check_number: "4821")
      scholarship = create(:scholarship, recipient: registrant, amount_cents: 10_000)
      create(:allocation, source: cash, allocatable: registration, amount: 30_000)
      create(:allocation, source: check, allocatable: registration, amount: 20_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 10_000)

      invoice = described_class.from_registration(registration)

      expect(invoice.entries.map(&:method)).to eq([ "Cash", "Check", "Scholarship" ])
      expect(invoice.entries.map(&:amount_cents)).to eq([ 30_000, 20_000, 10_000 ])
      check_entry = invoice.entries.find { |entry| entry.method == "Check" }
      expect(check_entry.reference).to eq("Check #4821")
    end

    context "with a snapshotted organization" do
      let(:organization) { create(:organization, name: "A Greater Hope") }

      before do
        create(:event_registration_organization, event_registration: registration, organization: organization)
        create(:address, addressable: organization, street_address: "PO Box 1477", city: "Victorville", state: "CA", zip_code: "92393")
      end

      it "bills the organization with its address but keeps the registrant as attention" do
        invoice = described_class.from_registration(registration)

        expect(invoice.bill_to_name).to eq("A Greater Hope")
        expect(invoice.attention).to eq("Helena Lopez")
        expect(invoice.bill_to_address_lines).to eq([ "PO Box 1477", "Victorville, CA 92393" ])
        expect(invoice.client_id).to eq(organization.id)
      end
    end
  end

  describe ".from_event" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }

    it "builds a blank template carrying only the event content" do
      invoice = described_class.from_event(event)

      expect(invoice.bill_to_name).to be_nil
      expect(invoice.attention).to be_nil
      expect(invoice.bill_to_address_lines).to eq([])

      item = invoice.line_items.first
      expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
      expect(item.quantity).to eq(1)
      expect(item.unit_price_cents).to eq(150_000)
      expect(invoice.total_cents).to eq(150_000)
    end
  end

  describe ".from_bulk_payment" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, form: form, event: event, role: "bulk_payment") }

    def add_answer(identifier, value)
      field = create(:form_field, form: form, field_identifier: identifier)
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
    end

    before do
      add_answer("payer_first_name", "Helena")
      add_answer("payer_last_name", "Lopez")
      add_answer("payer_organization", "A Greater Hope")
      add_answer("number_of_attendees", "8")
    end

    it "bills the payer's organization for every attendee submitted" do
      invoice = described_class.from_bulk_payment(submission)

      expect(invoice.bill_to_name).to eq("A Greater Hope")
      expect(invoice.attention).to eq("Helena Lopez")

      item = invoice.line_items.first
      expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
      expect(item.quantity).to eq(8)
      expect(item.unit_price_cents).to eq(150_000)
      expect(invoice.total_cents).to eq(1_200_000)
    end

    context "with attendee names and emails submitted" do
      before do
        attendees = [
          { first_name: "Ada", last_name: "Lovelace", email: "ada@example.com" },
          { first_name: "Grace", last_name: "Hopper", email: "grace@example.com" }
        ]
        add_answer("bulk_payment_attendees", attendees.to_json)
      end

      it "lists each attendee's name and email under the line item" do
        invoice = described_class.from_bulk_payment(submission)

        item = invoice.line_items.first
        expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
        expect(item.details).to eq([
          "Ada Lovelace — ada@example.com",
          "Grace Hopper — grace@example.com"
        ])
      end
    end

    it "leaves attendee details empty when none were submitted" do
      invoice = described_class.from_bulk_payment(submission)

      expect(invoice.line_items.first.details).to eq([])
    end
  end
end
