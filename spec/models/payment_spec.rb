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

  describe "compound payer/designation sgids" do
    let(:person) { create(:person) }
    let(:org) { create(:organization) }

    it "sets payer_type and organization from an organization payer sgid" do
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = org.to_sgid.to_s
      payment.additional_designation_sgid = person.to_sgid.to_s
      expect(payment).to be_valid

      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(org)
      expect(payment.person).to eq(person)
    end

    it "sets payer_type and person from a person payer sgid" do
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = person.to_sgid.to_s
      payment.additional_designation_sgid = org.to_sgid.to_s
      payment.valid?

      expect(payment.payer_type).to eq("Person")
      expect(payment.person).to eq(person)
      expect(payment.organization).to eq(org)
    end

    it "clears the slots when an empty additional designation is submitted" do
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = org.to_sgid.to_s
      payment.additional_designation_sgid = ""
      payment.valid?

      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(org)
      expect(payment.person).to be_nil
    end

    it "is invalid when the payer and designation are both people" do
      other_person = create(:person)
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = person.to_sgid.to_s
      payment.additional_designation_sgid = other_person.to_sgid.to_s

      expect(payment).not_to be_valid
      expect(payment.errors[:base]).to include(a_string_including("must be different kinds"))
    end

    it "is invalid when the payer and designation are both organizations" do
      other_org = create(:organization)
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = org.to_sgid.to_s
      payment.additional_designation_sgid = other_org.to_sgid.to_s

      expect(payment).not_to be_valid
      expect(payment.errors[:base]).to include(a_string_including("must be different kinds"))
    end

    it "is valid when the payer and designation are different kinds" do
      payment = build(:payment, person: nil, organization: nil, payer_type: nil)
      payment.payer_sgid = person.to_sgid.to_s
      payment.additional_designation_sgid = org.to_sgid.to_s

      expect(payment).to be_valid
    end

    it "exposes the current payer/designation as sgids for the form" do
      payment = build(:payment, person: person, organization: org, payer_type: "Organization")
      expect(GlobalID::Locator.locate_signed(payment.selected_payer.to_sgid.to_s)).to eq(org)
      expect(GlobalID::Locator.locate_signed(payment.selected_additional_designation.to_sgid.to_s)).to eq(person)
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

      it "returns all payments when no filters are given" do
        result = Payment.search_by_params({})
        expect(result).to include(person_payment, org_payment)
      end

      describe "search (metadata / stripe charge id)" do
        let!(:metadata_match) { create(:payment, metadata: { "note" => "reunion gala" }) }
        let!(:stripe_match) { create(:payment, stripe_charge_id: "ch_ABC123") }
        let!(:no_match) { create(:payment, metadata: { "note" => "something else" }) }

        it "matches on metadata contents" do
          result = Payment.search_by_params({ search: "reunion" })
          expect(result).to include(metadata_match)
          expect(result).not_to include(no_match, stripe_match)
        end

        it "matches on stripe charge id" do
          result = Payment.search_by_params({ search: "ch_ABC" })
          expect(result).to include(stripe_match)
          expect(result).not_to include(no_match, metadata_match)
        end

        it "returns all payments when search is blank" do
          result = Payment.search_by_params({ search: "" })
          expect(result).to include(metadata_match, stripe_match, no_match)
        end

        it "escapes LIKE wildcards in the query" do
          result = Payment.search_by_params({ search: "%" })
          expect(result).not_to include(metadata_match, stripe_match, no_match)
        end
      end

      describe "amount range" do
        let!(:small) { create(:payment, amount_cents: 500) }
        let!(:medium) { create(:payment, amount_cents: 1500) }
        let!(:large) { create(:payment, amount_cents: 5000) }

        it "filters by minimum dollar amount" do
          result = Payment.search_by_params({ amount_min: "15" })
          expect(result).to include(medium, large)
          expect(result).not_to include(small)
        end

        it "filters by maximum dollar amount" do
          result = Payment.search_by_params({ amount_max: "15" })
          expect(result).to include(small, medium)
          expect(result).not_to include(large)
        end

        it "filters by a min/max range" do
          result = Payment.search_by_params({ amount_min: "10", amount_max: "20" })
          expect(result).to include(medium)
          expect(result).not_to include(small, large)
        end

        it "returns all payments when the range is blank" do
          result = Payment.search_by_params({ amount_min: "", amount_max: "" })
          expect(result).to include(small, medium, large)
        end
      end

      describe "date range" do
        let!(:recent) { create(:payment, created_at: 2.days.ago) }
        let!(:old) { create(:payment, created_at: 2.months.ago) }

        it "defaults to the past month, excluding older payments" do
          result = Payment.search_by_params({})
          expect(result).to include(recent)
          expect(result).not_to include(old)
        end

        it "honors an explicit start date" do
          result = Payment.search_by_params({ start_date: 3.months.ago.to_date.to_s })
          expect(result).to include(recent, old)
        end

        it "honors an explicit end date" do
          result = Payment.search_by_params({ start_date: 3.months.ago.to_date.to_s, end_date: 1.month.ago.to_date.to_s })
          expect(result).to include(old)
          expect(result).not_to include(recent)
        end

        it "falls back to the default start date when blank" do
          result = Payment.search_by_params({ start_date: "", end_date: "" })
          expect(result).to include(recent)
          expect(result).not_to include(old)
        end

        it "ignores an unparseable date" do
          result = Payment.search_by_params({ start_date: "not-a-date" })
          expect(result).to include(recent)
          expect(result).not_to include(old)
        end
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
