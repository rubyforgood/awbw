require "rails_helper"

RSpec.describe Scholarship, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:recipient).class_name("Person") }
    it { is_expected.to belong_to(:grant).optional }
    it { is_expected.to have_one(:allocation).dependent(:destroy) }
  end

  describe "validations" do
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than_or_equal_to(0) }

    describe "recipient_must_match_allocation_registrant" do
      let(:event) { create(:event) }
      let(:person) { create(:person) }
      let(:registration) { create(:event_registration, event:, registrant: person) }

      it "is valid when recipient matches the allocation's registrant" do
        scholarship = build(:scholarship, recipient: person)
        scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
        expect(scholarship).to be_valid
      end

      it "is invalid when recipient differs from the allocation's registrant" do
        other_person = create(:person)
        scholarship = build(:scholarship, recipient: other_person)
        scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:recipient]).to include("must be the same person as the event registration's registrant")
      end
    end

    describe "within_grant_budget" do
      let(:grant) { create(:grant, amount_cents: 100_000) }

      it "is valid when the amount stays within the grant's funds" do
        expect(build(:scholarship, grant:, amount_cents: 60_000)).to be_valid
      end

      it "is invalid when the amount exceeds the grant's funds" do
        scholarship = build(:scholarship, grant:, amount_cents: 150_000)
        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:amount_cents]).to include("would exceed the grant's available funds")
      end

      it "accounts for other scholarships already drawn from the grant" do
        create(:scholarship, grant:, amount_cents: 70_000)
        scholarship = build(:scholarship, grant:, amount_cents: 40_000)
        expect(scholarship).not_to be_valid
      end

      it "is not constrained when no grant is set" do
        expect(build(:scholarship, grant: nil, amount_cents: 9_999_999)).to be_valid
      end
    end
  end

  describe "marking the event registration's scholarship_requested flag" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }
    let(:registration) { create(:event_registration, event:, registrant: person, scholarship_requested: false) }

    it "sets scholarship_requested to true on the connected event registration" do
      scholarship = build(:scholarship, recipient: person)
      scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
      scholarship.save!

      expect(registration.reload.scholarship_requested).to be(true)
    end

    it "leaves scholarship_requested true when the scholarship is destroyed" do
      scholarship = build(:scholarship, recipient: person)
      scholarship.build_allocation(allocatable: registration, amount: scholarship.amount_cents)
      scholarship.save!

      scholarship.destroy!

      expect(registration.reload.scholarship_requested).to be(true)
    end

    it "does nothing when the scholarship is not connected to an event registration" do
      expect { create(:scholarship, grant: create(:grant), recipient: person) }.not_to raise_error
    end
  end

  describe "agreement_signed_at stamping" do
    it "stamps the time when the agreement is first signed" do
      scholarship = create(:scholarship, agreement_signed: false)
      expect(scholarship.agreement_signed_at).to be_nil

      scholarship.update!(agreement_signed: true)
      expect(scholarship.agreement_signed_at).to be_present
    end

    it "clears the time when the agreement is unsigned" do
      scholarship = create(:scholarship, agreement_signed: true)
      expect(scholarship.agreement_signed_at).to be_present

      scholarship.update!(agreement_signed: false)
      expect(scholarship.agreement_signed_at).to be_nil
    end

    it "preserves the original time when re-saved while still signed" do
      scholarship = create(:scholarship, agreement_signed: true)
      original = scholarship.agreement_signed_at
      scholarship.update!(amount_cents: 2_000)

      expect(scholarship.reload.agreement_signed_at).to be_within(1.second).of(original)
    end
  end
end
