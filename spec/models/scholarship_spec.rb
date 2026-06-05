require "rails_helper"

RSpec.describe Scholarship, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:recipient).class_name("Person") }
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
        scholarship.build_allocation(allocatable: registration, amount: 0)
        expect(scholarship).to be_valid
      end

      it "is invalid when recipient differs from the allocation's registrant" do
        other_person = create(:person)
        scholarship = build(:scholarship, recipient: other_person)
        scholarship.build_allocation(allocatable: registration, amount: 0)
        expect(scholarship).not_to be_valid
        expect(scholarship.errors[:recipient]).to include("must be the same person as the event registration's registrant")
      end
    end
  end
end
