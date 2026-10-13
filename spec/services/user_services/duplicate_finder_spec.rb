require "rails_helper"

RSpec.describe UserServices::DuplicateFinder do
  describe "#groups" do
    it "groups logins that share a person, most recently updated first" do
      person = create(:person, first_name: "Jane", last_name: "Doe", user: nil)
      older = create(:user, person: person, updated_at: 1.week.ago)
      recent = create(:user, person: person, updated_at: 1.hour.ago)

      groups = described_class.new.groups

      expect(groups.size).to eq(1)
      expect(groups.first.records).to eq([ recent, older ])
      expect(groups.first.label).to eq("Jane Doe")
      expect(groups.first.reasons).to eq([ "Same person" ])
    end

    it "leads with a login that can sign in over a more recently updated one that can't" do
      person = create(:person, user: nil)
      usable = create(:user, person: person, updated_at: 1.week.ago)
      unconfirmed = create(:user, :unconfirmed, person: person, updated_at: 1.hour.ago)

      expect(described_class.new.groups.first.records).to eq([ usable, unconfirmed ])
    end

    it "ignores a person with one login and logins without a person" do
      create(:user, :with_person)
      create(:user, person: nil)
      create(:user, person: nil)

      expect(described_class.new.groups).to be_empty
    end
  end
end
