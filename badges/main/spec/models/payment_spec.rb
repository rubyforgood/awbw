require "rails_helper"

RSpec.describe Payment, type: :model do
  describe "associations" do
    subject { create(:payment) }

    it { should belong_to(:payer).required }
    it { should belong_to(:payable).required }
    it { should belong_to(:event).optional }
  end

  describe "validations" do
    describe "with build subject" do
      subject { build(:payment) }

      it { should validate_presence_of(:currency) }
      it { should validate_presence_of(:status) }
      it { should validate_numericality_of(:amount_cents) }
      it { should validate_inclusion_of(:status).in_array(Payment::STRIPE_PAYMENT_STATUSES) }
      it { should validate_inclusion_of(:payment_type).in_array(Payment::PAYMENT_TYPES) }
    end

    describe "stripe_payment_intent_id conditional presence" do
      it "requires stripe_payment_intent_id for stripe payments" do
        payment = build(:payment, payment_type: "stripe", stripe_payment_intent_id: nil)
        expect(payment).not_to be_valid
        expect(payment.errors[:stripe_payment_intent_id]).to be_present
      end

      it "does not require stripe_payment_intent_id for scholarship payments" do
        payment = build(:payment, :scholarship, :succeeded, amount_cents: 1000)
        expect(payment).to be_valid
      end
    end

    describe "with create subject for uniqueness" do
      subject { create(:payment) }

      it { should validate_uniqueness_of(:stripe_payment_intent_id).case_insensitive }
      it { should validate_uniqueness_of(:stripe_charge_id).case_insensitive.allow_nil }
    end

    describe "defaults" do
      it "defaults currency to 'usd'" do
        payment = Payment.new
        expect(payment.currency).to eq("usd")
      end

      it "defaults status to 'pending'" do
        payment = Payment.new
        expect(payment.status).to eq("pending")
      end
    end
  end

  describe "constants" do
    it "defines PAYMENT_TYPES" do
      expect(Payment::PAYMENT_TYPES).to eq(%w[stripe scholarship check purchase_order other refund])
    end

    it "defines STRIPE_PAYMENT_STATUSES" do
      expect(Payment::STRIPE_PAYMENT_STATUSES).to eq(%w[
        pending
        requires_action
        processing
        succeeded
        failed
        canceled
        refunded
        partially_refunded
      ])
    end
  end

  describe "scopes" do
    let(:user) { create(:user) }
    let(:event1) { create(:event) }
    let(:event2) { create(:event) }

    describe ".for_payable" do
      let!(:payment1) { create(:payment, payable: event1) }
      let!(:payment2) { create(:payment, payable: event2) }

      it "returns payments for the specified payable" do
        expect(Payment.for_payable(event1)).to include(payment1)
        expect(Payment.for_payable(event1)).not_to include(payment2)
      end
    end

    describe ".successful" do
      let!(:succeeded_payment) { create(:payment, status: "succeeded") }
      let!(:pending_payment) { create(:payment, status: "pending") }
      let!(:failed_payment) { create(:payment, status: "failed") }

      it "returns only payments with succeeded status" do
        expect(Payment.successful).to include(succeeded_payment)
        expect(Payment.successful).not_to include(pending_payment)
        expect(Payment.successful).not_to include(failed_payment)
      end
    end

    describe ".scholarships" do
      let!(:scholarship_payment) { create(:payment, :scholarship, :succeeded, amount_cents: 1000) }
      let!(:stripe_payment) { create(:payment, :succeeded) }

      it "returns only scholarship payments" do
        expect(Payment.scholarships).to include(scholarship_payment)
        expect(Payment.scholarships).not_to include(stripe_payment)
      end
    end

    describe ".pendingish" do
      let!(:pending_payment) { create(:payment, status: "pending") }
      let!(:requires_action_payment) { create(:payment, status: "requires_action") }
      let!(:processing_payment) { create(:payment, status: "processing") }
      let!(:succeeded_payment) { create(:payment, status: "succeeded") }
      let!(:failed_payment) { create(:payment, status: "failed") }

      it "returns payments with pending, requires_action, or processing status" do
        result = Payment.pendingish
        expect(result).to include(pending_payment)
        expect(result).to include(requires_action_payment)
        expect(result).to include(processing_payment)
        expect(result).not_to include(succeeded_payment)
        expect(result).not_to include(failed_payment)
      end
    end
  end
end
