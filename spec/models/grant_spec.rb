require "rails_helper"

RSpec.describe Grant, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:donor) }
    it { is_expected.to belong_to(:created_by).class_name("User").optional }
    it { is_expected.to belong_to(:updated_by).class_name("User").optional }
    it { is_expected.to have_many(:scholarships).dependent(:restrict_with_error) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:amount_cents).is_greater_than_or_equal_to(0) }

    it "is valid with an organization donor" do
      expect(build(:grant)).to be_valid
    end

    it "is valid with a person donor" do
      expect(build(:grant, :donated_by_person)).to be_valid
    end
  end

  describe "money accessors" do
    it "exposes the amount in dollars" do
      expect(build(:grant, amount_cents: 250_000).amount_dollars).to eq(2_500)
    end

    it "stores dollars as cents" do
      grant = build(:grant)
      grant.amount_dollars = "1234.56"
      expect(grant.amount_cents).to eq(123_456)
    end
  end

  describe "#donor_sgid" do
    it "round-trips a donor through a signed global id" do
      organization = create(:organization)
      grant = build(:grant)
      grant.donor_sgid = organization.to_signed_global_id.to_s
      expect(grant.donor).to eq(organization)
      expect(GlobalID::Locator.locate_signed(grant.donor_sgid)).to eq(organization)
    end
  end

  describe "list accessors" do
    let(:grant) { build(:grant, eligibility_criteria: "One\n\n  Two  \n", tasks: "A\nB") }

    it "splits eligibility criteria into a trimmed list" do
      expect(grant.eligibility_criteria_list).to eq([ "One", "Two" ])
    end

    it "splits tasks into a list" do
      expect(grant.task_list).to eq([ "A", "B" ])
    end
  end

  describe "budget helpers" do
    let(:grant) { create(:grant, amount_cents: 100_000) }

    it "sums awarded scholarships" do
      create(:scholarship, grant:, amount_cents: 30_000)
      create(:scholarship, grant:, amount_cents: 20_000)
      expect(grant.scholarships_total_cents).to eq(50_000)
    end

    it "reports remaining funds" do
      create(:scholarship, grant:, amount_cents: 40_000)
      expect(grant.remaining_cents).to eq(60_000)
      expect(grant.remaining_dollars).to eq(600)
    end
  end
end
