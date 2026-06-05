require "rails_helper"

RSpec.describe Payment, type: :model do
  describe "associations" do
    subject { create(:payment) }

    it { should belong_to(:person).optional }
    it { should belong_to(:organization).optional }
  end

  describe "validations" do
    subject { build(:payment) }

    it { should validate_presence_of(:currency) }
    it { should validate_numericality_of(:amount_cents) }

    describe "payer_type" do
      it "is required when auto_set cannot determine it" do
        payment = build(:payment, person: nil, organization: nil, payer_type: nil)
        expect(payment).not_to be_valid
        expect(payment.errors[:payer_type]).to include("can't be blank")
      end

      it "auto-sets from person when only person is present" do
        payment = build(:payment, person: create(:person), organization: nil, payer_type: nil)
        expect(payment).to be_valid
        expect(payment.payer_type).to eq("Person")
      end

      it "auto-sets from organization when only organization is present" do
        payment = build(:payment, person: nil, organization: create(:organization), payer_type: nil)
        expect(payment).to be_valid
        expect(payment.payer_type).to eq("Organization")
      end

      it "accepts valid values" do
        payment = build(:payment, person: nil, organization: create(:organization), payer_type: "Organization")
        expect(payment).to be_valid
      end

      it "rejects invalid values when both person and organization are present" do
        person = create(:person)
        org = create(:organization)
        payment = build(:payment, person: person, organization: org, payer_type: "Invalid")
        expect(payment).not_to be_valid
        expect(payment.errors[:payer_type]).to be_present
      end
    end

    describe "at_least_one_payer" do
      it "is invalid without a person or organization" do
        payment = build(:payment, person: nil, organization: nil)
        expect(payment).not_to be_valid
        expect(payment.errors[:base]).to include("At least one payer (person or organization) must be present")
      end

      it "is valid with a person" do
        payment = build(:payment, person: create(:person), organization: nil)
        expect(payment).to be_valid
      end

      it "is valid with an organization" do
        payment = build(:payment, person: nil, organization: create(:organization))
        expect(payment).to be_valid
      end
    end
  end

  describe "constants" do
    it "defines PAYER_TYPES" do
      expect(Payment::PAYER_TYPES).to eq(%w[Person Organization])
    end
  end

  describe "scopes" do
    let(:person1) { create(:person) }
    let(:person2) { create(:person) }
    let(:org) { create(:organization) }

    describe ".by_type" do
      let!(:cash_payment) { create(:payment, type: "CashPayment") }
      let!(:check_payment) { create(:payment, type: "CheckPayment", check_number: "123") }

      it "filters by payment type" do
        expect(Payment.by_type("CashPayment")).to include(cash_payment)
        expect(Payment.by_type("CashPayment")).not_to include(check_payment)
      end
    end

    describe ".search_by_params" do
      let!(:person_payment) { create(:payment, person: person1, organization: nil) }
      let!(:org_payment) { create(:payment, person: nil, organization: org) }

      it "filters by person_id" do
        result = Payment.search_by_params({ person_id: person1.id })
        expect(result).to include(person_payment)
        expect(result).not_to include(org_payment)
      end

      it "filters by organization_id" do
        result = Payment.search_by_params({ organization_id: org.id })
        expect(result).to include(org_payment)
        expect(result).not_to include(person_payment)
      end

      it "filters by payer_type" do
        result = Payment.search_by_params({ payer_type: "Person" })
        expect(result).to include(person_payment)
        expect(result).not_to include(org_payment)
      end
    end

    describe ".has_remaining" do
      let!(:has_remaining) { create(:payment, amount_cents_remaining: 500) }
      let!(:fully_allocated) { create(:payment, amount_cents_remaining: 0) }

      it "filters payments with remaining amount" do
        expect(Payment.has_remaining("yes")).to include(has_remaining)
        expect(Payment.has_remaining("yes")).not_to include(fully_allocated)
      end

      it "filters payments with no remaining amount" do
        expect(Payment.has_remaining("no")).to include(fully_allocated)
        expect(Payment.has_remaining("no")).not_to include(has_remaining)
      end
    end
  end

  describe "#payer" do
    it "returns the person when payer_type is Person" do
      person = create(:person)
      payment = build(:payment, person: person, organization: nil)
      expect(payment.payer).to eq(person)
    end

    it "returns the organization when payer_type is Organization" do
      org = create(:organization)
      payment = create(:payment, person: nil, organization: org)
      expect(payment.payer).to eq(org)
    end
  end
end
