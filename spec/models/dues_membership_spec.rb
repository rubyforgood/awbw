require "rails_helper"

RSpec.describe DuesMembership, type: :model do
  describe "validations" do
    it "allows a nil rate_cents, meaning the standard rate" do
      expect(build(:dues_membership, rate_cents: nil)).to be_valid
    end

    it "allows a zero rate_cents, meaning a comped member" do
      expect(build(:dues_membership, rate_cents: 0)).to be_valid
    end

    it "rejects a negative rate_cents" do
      membership = build(:dues_membership, rate_cents: -1)
      expect(membership).not_to be_valid
      expect(membership.errors[:rate_cents]).to be_present
    end

    it "rejects a second uncancelled membership for the same person" do
      person = create(:person)
      create(:dues_membership, person: person)

      second = build(:dues_membership, person: person)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to match(/already has a dues membership/)
    end

    it "allows a new membership once the previous one is cancelled" do
      person = create(:person)
      create(:dues_membership, :cancelled, person: person)

      expect(build(:dues_membership, person: person)).to be_valid
    end

    it "allows two people to each have an uncancelled membership" do
      create(:dues_membership)
      expect(build(:dues_membership)).to be_valid
    end

    it "does not treat a persisted membership as its own duplicate" do
      membership = create(:dues_membership)
      membership.rate_cents = 1_500
      expect(membership).to be_valid
    end
  end

  describe "#cancelled?" do
    it "is false while cancelled_at is blank" do
      expect(build(:dues_membership)).not_to be_cancelled
    end

    it "is true once cancelled_at is stamped" do
      expect(build(:dues_membership, :cancelled)).to be_cancelled
    end
  end

  describe "scopes" do
    let!(:open_membership) { create(:dues_membership) }
    let!(:cancelled_membership) { create(:dues_membership, :cancelled) }

    it "separates cancelled from uncancelled" do
      expect(described_class.not_cancelled).to contain_exactly(open_membership)
      expect(described_class.cancelled).to contain_exactly(cancelled_membership)
    end
  end

  describe "associations" do
    it "destroys its terms with it" do
      membership = create(:dues_membership)
      create(:dues_registration, dues_membership: membership)

      expect { membership.destroy }.to change(DuesRegistration, :count).by(-1)
    end

    it "is reachable from the person, along with their terms" do
      membership = create(:dues_membership)
      term = create(:dues_registration, dues_membership: membership)

      expect(membership.person.dues_memberships).to contain_exactly(membership)
      expect(membership.person.dues_registrations).to contain_exactly(term)
    end
  end
end
