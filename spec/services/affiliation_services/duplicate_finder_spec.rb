# frozen_string_literal: true

require "rails_helper"

RSpec.describe AffiliationServices::DuplicateFinder do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:keep) { create(:affiliation, person: person, organization: organization, title: "Facilitator") }

  def copy_of(original, **attrs)
    original.dup.tap do |copy|
      copy.assign_attributes(attrs)
      copy.save!(validate: false)
    end
  end

  it "groups a person's identical affiliations, survivor first" do
    copy = copy_of(keep, title: " Facilitator ")

    groups = described_class.new.groups

    expect(groups.map(&:person)).to eq([ person ])
    expect(groups.first.duplicate_sets).to eq([ [ keep, copy ] ])
    expect(groups.first.merged_count).to eq(1)
  end

  it "skips affiliations that differ in title, dates, or status" do
    copy_of(keep, title: "Coordinator")
    copy_of(keep, start_date: Date.new(2025, 1, 1))
    copy_of(keep, inactive: true)

    expect(described_class.new.groups).to be_empty
  end
end
