require "rails_helper"

RSpec.describe OrganizationServices::NameMatcher do
  subject(:matcher) { described_class.new }

  let!(:organization) { create(:organization, name: "Sunrise Center") }

  it "matches an exact name, ignoring case" do
    expect(matcher.call("sunrise center")).to have_attributes(organization: organization, basis: :exact)
  end

  it "matches a name that differs only by punctuation" do
    expect(matcher.call("Sunrise-Center!")).to have_attributes(organization: organization, basis: :normalized)
  end

  it "matches a name that differs only by a legal suffix" do
    expect(matcher.call("Sunrise Center LLC")).to have_attributes(organization: organization, basis: :suffixless)
  end

  it "matches nothing when a loose name fits more than one organization" do
    create(:organization, name: "Sunrise Center, Inc.")

    expect(matcher.call("Sunrise Center Corp")).to be_nil
  end

  it "matches nothing for an unknown or blank name" do
    expect(matcher.call("Moonrise Center")).to be_nil
    expect(matcher.call(" ")).to be_nil
  end
end
