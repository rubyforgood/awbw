# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliationServices::FoldLegacyLeaders do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  def affiliation(title, **attributes)
    create(:affiliation, person:, organization:, title:, **attributes)
  end

  def row_for(leader) = described_class.new.rows.find { |row| row.leader == leader }

  def apply(outcome) = described_class.new.apply(outcome: outcome.transform_keys { |leader| leader.id.to_s })

  describe "#rows" do
    it "suggests merging into a Facilitator twin with the same dates" do
      twin = affiliation("Facilitator")
      leader = affiliation("Leader")

      expect(row_for(leader)).to have_attributes(twin:, same_dates: true, suggestion: "merge")
    end

    it "suggests renaming when no Facilitator row covers its stretch" do
      affiliation("Facilitator", start_date: Date.new(2010, 1, 1), end_date: Date.new(2012, 12, 31))
      leader = affiliation("Leader", start_date: Date.new(2019, 4, 1), end_date: Date.new(2025, 7, 1))

      row = row_for(leader)
      expect(row).to have_attributes(twin: nil, suggestion: "rename")
      expect(row.choices).not_to include("merge")
    end

    it "suggests leaving one that overlaps a Facilitator row with different dates" do
      twin = affiliation("Facilitator", start_date: Date.new(2018, 1, 1), end_date: Date.new(2022, 12, 31))
      leader = affiliation("Leader", start_date: Date.new(2019, 4, 1), end_date: Date.new(2025, 7, 1))

      expect(row_for(leader)).to have_attributes(twin:, same_dates: false, suggestion: "keep")
    end
  end

  describe "#planned_changes" do
    it "plans only the rows given a choice they offer, skipping keep" do
      leader = affiliation("Leader")
      other = affiliation("Leader", start_date: Date.new(2019, 1, 1))

      changes = described_class.new.planned_changes(outcome: { leader.id.to_s => "merge", other.id.to_s => "keep" })

      expect(changes).to be_empty
      expect(described_class.new.planned_changes(outcome: { leader.id.to_s => "rename" }).map(&:action)).to eq([ "rename" ])
    end
  end

  describe "#apply" do
    it "merges a Leader row into its twin, carrying its codes and comments" do
      twin = affiliation("Facilitator", primary_contact: false, filemaker_code: "P0001")
      leader = affiliation("Leader", primary_contact: true, filemaker_code: "PS0001")
      leader.comments.create!(body: "Met at the 2019 training")

      expect(apply(leader => "merge")).to eq(1)

      expect(Affiliation.exists?(leader.id)).to be(false)
      expect(twin.reload).to have_attributes(primary_contact: true, filemaker_code: "P0001, PS0001")
      expect(twin.comments.pluck(:body)).to contain_exactly("Met at the 2019 training", a_string_including("Leader", "##{leader.id}"))
    end

    it "merges two Leader rows sharing one twin, keeping both codes" do
      twin = affiliation("Facilitator", primary_contact: true)
      first = affiliation("Leader", filemaker_code: "P0001")
      # The model refuses an identical row now; prod's pairs predate that.
      second = affiliation("Placeholder", filemaker_code: "P0002").tap { |row| row.update_column(:title, "Leader") }

      apply(first => "merge", second => "merge")

      expect(person.affiliations.reload).to contain_exactly(twin)
      expect(twin.reload.filemaker_code).to eq("P0001, P0002")
    end

    it "renames a Leader row to a primary-contact Facilitator" do
      leader = affiliation("Leader", primary_contact: false)

      apply(leader => "rename")

      expect(leader.reload).to have_attributes(title: "Facilitator", primary_contact: true)
      expect(leader.comments.sole).to have_attributes(topic: described_class::COMMENT_TOPIC, body: a_string_including("Titled Leader"))
    end

    it "renames and ends one, keeping an end date it already has" do
      open_leader = affiliation("Leader")
      dated = affiliation("Leader", start_date: Date.new(2019, 1, 1), end_date: Date.new(2020, 1, 1))

      apply(open_leader => "end", dated => "end")

      expect(open_leader.reload).to have_attributes(title: "Facilitator", end_date: Date.current, inactive: true)
      expect(dated.reload).to have_attributes(title: "Facilitator", end_date: Date.new(2020, 1, 1), inactive: true)
    end

    it "deletes one outright" do
      leader = affiliation("Leader")

      apply(leader => "delete")

      expect(Affiliation.exists?(leader.id)).to be(false)
    end
  end
end
