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

    it "lists scholarship and discount credits as ledger entries and counts them toward amount paid" do
      payment = create(:payment, type: "CashPayment", amount_cents: 90_000)
      scholarship = create(:scholarship, recipient: registrant, amount_cents: 50_000)
      discount = create(:discount, amount_cents: 10_000)
      create(:allocation, source: payment, allocatable: registration, amount: 90_000)
      create(:allocation, source: scholarship, allocatable: registration, amount: 50_000)
      create(:allocation, source: discount, allocatable: registration, amount: 10_000)

      receipt = described_class.from_registration(registration)

      # Each allocation is its own ledger entry (so payments and credits are
      # distinguishable), while the summary's amount paid reconciles to the total.
      expect(receipt.entries.map(&:method)).to include("Cash", "Scholarship", "Discount")
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

  describe ".from_bulk_payment" do
    let(:event) { create(:event, title: "AWBW 2-Day Art Facilitator Training", cost_cents: 150_000) }
    let(:submitter) { create(:person, first_name: "Sam", last_name: "Submitter") }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, person: submitter, form: form, event: event, role: "bulk_payment") }

    def answer(identifier, value)
      field = create(:form_field, form: form, answer_type: :free_form_input_one_line, field_identifier: identifier, name: identifier)
      submission.form_answers.create!(form_field: field, submitted_answer: value, question_name_when_answered: identifier)
    end

    before do
      answer("number_of_attendees", "3")
      # Form-captured payer fields that must NOT drive the receipt: the connected
      # payment's payer is authoritative (an admin may record it against someone
      # other than the form submitter).
      answer("payer_first_name", "Sam")
      answer("payer_last_name", "Submitter")
      answer("payer_organization", "Someone Else Inc")
    end

    context "when an organization paid" do
      let(:organization) { create(:organization, name: "Northside Shelter", email: "billing@northside.org") }
      let(:contact) { create(:person, first_name: "Dana", last_name: "Okafor") }

      before do
        create(:address, addressable: organization, street_address: "12 Main St", city: "Denver", state: "CO", zip_code: "80202")
        create(:payment, form_submission: submission, organization: organization, person: contact,
               payer_type: "Organization", type: "CashPayment", amount_cents: 450_000)
      end

      it "bills the payment's organization payer, not the form submitter" do
        receipt = described_class.from_bulk_payment(submission.reload)

        expect(receipt.number).to eq("RCPT-B-#{submission.id}")
        expect(receipt.bill_to_name).to eq("Northside Shelter")
        expect(receipt.bill_to_email).to eq("billing@northside.org")
        expect(receipt.attention).to eq("Dana Okafor")
        expect(receipt.client_id).to eq(organization.id)
        expect(receipt.bill_to_address_lines).to eq([ "12 Main St", "Denver, CO 80202" ])
      end

      it "itemizes the event charge per attendee and records the amount paid" do
        receipt = described_class.from_bulk_payment(submission.reload)

        item = receipt.line_items.first
        expect(item.description).to eq("AWBW 2-Day Art Facilitator Training")
        expect(item.quantity).to eq(3)
        expect(item.unit_price_cents).to eq(150_000)
        expect(receipt.amount_paid_cents).to eq(450_000)
        # A bulk payment records what was paid; it has no owed-balance concept.
        expect(receipt.settles_balance?).to be(false)
      end
    end

    context "when a person paid" do
      let(:payer) { create(:person, first_name: "Alex", last_name: "Payer") }

      before do
        create(:payment, form_submission: submission, person: payer, organization: nil,
               payer_type: "Person", type: "CheckPayment", amount_cents: 450_000, check_number: "7788")
      end

      it "bills the paying person directly" do
        receipt = described_class.from_bulk_payment(submission.reload)

        expect(receipt.bill_to_name).to eq("Alex Payer")
        expect(receipt.attention).to eq("Alex Payer")
        expect(receipt.bill_to_email).to eq(payer.preferred_email)
        expect(receipt.client_id).to eq(payer.id)
      end

      it "records the payment as the one ledger entry, labelled by method" do
        receipt = described_class.from_bulk_payment(submission.reload)

        expect(receipt.entries.size).to eq(1)
        entry = receipt.entries.first
        expect(entry.method).to eq("Check")
        expect(entry.reference).to eq("Check #7788")
        expect(entry.amount_cents).to eq(450_000)
      end
    end
  end
end
