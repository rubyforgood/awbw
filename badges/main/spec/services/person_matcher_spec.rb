require "rails_helper"

RSpec.describe PersonMatcher do
  let!(:person) { create(:person, user: nil, first_name: "Jamie", legal_first_name: "Jamison", last_name: "Rivera-Cole", email: "jamie@example.com", email_2: "jamie.work@example.com") }

  it "matches on primary email, last name, and first name ignoring case and padding" do
    expect(described_class.call(email: " JAMIE@example.com ", last_name: "rivera-cole ", first_names: [ "JAMIE" ])).to eq(person)
  end

  it "matches on the secondary email" do
    expect(described_class.call(email: "jamie.work@example.com", last_name: "Rivera-Cole", first_names: [ "Jamie" ])).to eq(person)
  end

  it "matches on the login email" do
    create(:user, person: person, email: "login@example.com")

    expect(described_class.call(email: "login@example.com", last_name: "Rivera-Cole", first_names: [ "Jamie" ])).to eq(person)
  end

  it "matches a submitted look-alike dash against the stored hyphen" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Rivera–Cole", first_names: [ "Jamie" ])).to eq(person)
  end

  it "matches any of the given first names against the legal first name" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Rivera-Cole", first_names: [ "Jamison", nil ])).to eq(person)
  end

  it "does not match a different first name" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Rivera-Cole", first_names: [ "Dana" ])).to be_nil
  end

  it "does not match a different last name" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Cole", first_names: [ "Jamie" ])).to be_nil
  end

  it "matches on email and last name alone when no first names are given" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Rivera-Cole")).to eq(person)
  end

  it "returns nil when first names are given but all blank" do
    expect(described_class.call(email: "jamie@example.com", last_name: "Rivera-Cole", first_names: [ "", nil ])).to be_nil
  end

  it "returns nil without an email or last name" do
    expect(described_class.call(email: "", last_name: "Rivera-Cole")).to be_nil
    expect(described_class.call(email: "jamie@example.com", last_name: nil)).to be_nil
  end
end
