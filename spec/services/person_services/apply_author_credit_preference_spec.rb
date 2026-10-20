require "rails_helper"

RSpec.describe PersonServices::ApplyAuthorCreditPreference do
  let(:person) { create(:person, display_name_preference: "full_name", anonymous_contributions: false) }

  it "turns on anonymous contributions and keeps the name format" do
    described_class.call(person: person, preference: "anonymous")

    expect(person.reload.anonymous_contributions).to be(true)
    expect(person.display_name_preference).to eq("full_name")
  end

  it "sets the name format and turns off anonymous contributions" do
    person.update!(anonymous_contributions: true)

    described_class.call(person: person, preference: "last_name_only")

    expect(person.reload.display_name_preference).to eq("last_name_only")
    expect(person.anonymous_contributions).to be(false)
  end

  it "ignores a blank or unknown preference" do
    expect(described_class.call(person: person, preference: "")).to be(false)
    expect(described_class.call(person: person, preference: "nickname")).to be(false)
    expect(person.reload.display_name_preference).to eq("full_name")
  end

  it "is a no-op without a person" do
    expect(described_class.call(person: nil, preference: "anonymous")).to be(false)
  end
end
