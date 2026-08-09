require "rails_helper"

RSpec.describe ScholarshipsGrouping do
  describe "#funder_groups" do
    it "nests grants under their shared funder and sums each level" do
      funder = create(:person, first_name: "Elisa", last_name: "Perlman")
      grant_2025 = create(:grant, name: "Elisa 2025", funder: funder, amount_cents: 1_000_000)
      grant_2026 = create(:grant, name: "Elisa 2026", funder: funder, amount_cents: 1_000_000)
      create(:scholarship, grant: grant_2025, amount_cents: 100_000)
      create(:scholarship, grant: grant_2026, amount_cents: 50_000)

      groups = described_class.new(Scholarship.all).funder_groups

      expect(groups.map(&:name)).to eq([ "Elisa Perlman" ])
      funder = groups.first
      expect(funder.count).to eq(2)
      expect(funder.total_cents).to eq(150_000)
      expect(funder.grant_groups.map { |g| g.grant.name }).to eq([ "Elisa 2025", "Elisa 2026" ])
    end

    it "puts grant-free scholarships in an Unfunded group sorted last" do
      create(:scholarship, grant: create(:grant, name: "Aardvark Fund", funder: create(:organization, name: "Aardvark")))
      create(:scholarship, grant: nil)

      names = described_class.new(Scholarship.all).funder_groups.map(&:name)

      expect(names.last).to eq("Unfunded")
    end

    it "orders recipients within a grant by name" do
      grant = create(:grant, amount_cents: 1_000_000)
      create(:scholarship, grant: grant, recipient: create(:person, first_name: "Zoe", last_name: "Z"))
      create(:scholarship, grant: grant, recipient: create(:person, first_name: "Amy", last_name: "A"))

      grant_group = described_class.new(Scholarship.all).funder_groups.first.grant_groups.first

      expect(grant_group.scholarships.map { |s| s.recipient.full_name }).to eq([ "Amy A", "Zoe Z" ])
    end
  end
end
