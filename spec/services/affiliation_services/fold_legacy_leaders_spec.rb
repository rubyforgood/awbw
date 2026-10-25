# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliationServices::FoldLegacyLeaders do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  def affiliation(title, **attributes)
    create(:affiliation, person:, organization:, title:, **attributes)
  end

  it "merges a Leader row into its same-dates Facilitator twin, carrying its codes and comments" do
    twin = affiliation("Facilitator", primary_contact: false, filemaker_code: "P0001")
    leader = affiliation("Leader", primary_contact: true, filemaker_code: "PS0001")
    leader.comments.create!(body: "Met at the 2019 training")

    expect(described_class.new.call).to eq(1)

    expect(Affiliation.exists?(leader.id)).to be(false)
    expect(twin.reload).to have_attributes(primary_contact: true, filemaker_code: "P0001, PS0001")
    expect(twin.comments.pluck(:body)).to contain_exactly("Met at the 2019 training", a_string_including("Leader", "##{leader.id}"))
  end

  it "merges two Leader rows sharing one twin into it" do
    twin = affiliation("Facilitator", primary_contact: true)
    affiliation("Leader", primary_contact: true)
    # The model refuses an identical row now; prod's pairs predate that.
    affiliation("Placeholder", primary_contact: true).update_column(:title, "Leader")

    described_class.new.call

    expect(person.affiliations.reload).to contain_exactly(twin)
    expect(twin.comments.where(topic: described_class::COMMENT_TOPIC).count).to eq(2)
  end

  it "renames a Leader row with no Facilitator row in its stretch" do
    affiliation("Facilitator", start_date: Date.new(2010, 1, 1), end_date: Date.new(2012, 12, 31))
    leader = affiliation("Leader", start_date: Date.new(2019, 4, 1), end_date: Date.new(2025, 7, 1), primary_contact: false)

    expect(described_class.new.call).to eq(1)

    expect(leader.reload).to have_attributes(title: "Facilitator", primary_contact: true)
    expect(leader.comments.sole).to have_attributes(topic: described_class::COMMENT_TOPIC, body: a_string_including("Titled Leader"))
  end

  it "leaves a Leader row overlapping a Facilitator row with different dates for an admin" do
    affiliation("Facilitator", start_date: Date.new(2018, 1, 1), end_date: Date.new(2022, 12, 31))
    leader = affiliation("Leader", start_date: Date.new(2019, 4, 1), end_date: Date.new(2025, 7, 1))

    expect(described_class.new.call).to eq(0)

    expect(leader.reload.title).to eq("Leader")
    expect(leader.comments).to be_empty
  end
end
