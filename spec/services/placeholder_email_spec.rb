require "rails_helper"

RSpec.describe PlaceholderEmail do
  it "numbers addresses on the configured domain" do
    expect(described_class.first).to eq("1@example.com")
    expect(described_class.at(4)).to eq("4@example.com")
  end

  it "recognizes a numbered address and reads its number back" do
    expect(described_class).to be_match("3@example.com")
    expect(described_class.number_in("3@example.com")).to eq(3)
    expect(described_class).not_to be_match("jane@example.com")
    expect(described_class.number_in("jane@example.com")).to be_nil
  end

  it "treats any address on the domain as seeded data" do
    expect(described_class).to be_domain_address("JANE@Example.com")
    expect(described_class).not_to be_domain_address("jane@awbw.org")
  end

  context "when the domain changes" do
    before { allow(Setting).to receive(:placeholder_email_domain).and_return("placeholder.invalid") }

    it "builds every form of the match from that one value" do
      expect(described_class.first).to eq("1@placeholder.invalid")
      expect(described_class).to be_match("2@placeholder.invalid")
      expect(described_class.sql_pattern).to eq("^[0-9]+@placeholder\\.invalid$")
    end

    it "carries into the database scope, so Ruby and SQL agree" do
      marked = create(:person, user: nil, email: described_class.first)
      create(:person, user: nil, email: "1@example.com")

      expect(Person.placeholder_email).to contain_exactly(marked)
    end
  end
end
