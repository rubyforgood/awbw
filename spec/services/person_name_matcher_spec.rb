require "rails_helper"

RSpec.describe PersonNameMatcher do
  let(:organization) { create(:organization) }

  it "matches the only person with the name" do
    person = create(:person, first_name: "Sam", last_name: "Sample")

    expect(described_class.call(first_name: "sam", last_name: "SAMPLE")).to have_attributes(person: person, basis: :name)
  end

  it "matches on the legal first name too" do
    person = create(:person, first_name: "Sammy", legal_first_name: "Samuel", last_name: "Sample")

    expect(described_class.call(first_name: "Samuel", last_name: "Sample").person).to eq(person)
  end

  it "breaks a tie with the organization the person is affiliated with" do
    create(:person, first_name: "Sam", last_name: "Sample")
    affiliated = create(:person, first_name: "Sam", last_name: "Sample")
    create(:affiliation, person: affiliated, organization: organization)

    result = described_class.call(first_name: "Sam", last_name: "Sample", organization: organization)
    expect(result).to have_attributes(person: affiliated, basis: :name_and_organization)
  end

  it "matches no one when the name is shared and the organization doesn't settle it" do
    create_list(:person, 2, first_name: "Sam", last_name: "Sample")

    expect(described_class.call(first_name: "Sam", last_name: "Sample", organization: organization))
      .to have_attributes(person: nil, candidate_count: 2)
  end
end
