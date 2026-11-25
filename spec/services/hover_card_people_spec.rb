require "rails_helper"

RSpec.describe HoverCardPeople do
  it "indexes each named person by id with their hover card data loaded" do
    person = create(:person)
    create(:affiliation, person: person, start_date: 1.year.ago)
    create(:event_registration, registrant: person)
    create(:membership, person: person)

    loaded = described_class.new([ person.id, person.id, nil ]).by_id.fetch(person.id)

    expect(loaded.association(:affiliations)).to be_loaded
    expect(loaded.affiliations.first.association(:organization)).to be_loaded
    expect(loaded.association(:event_registrations)).to be_loaded
    expect(loaded.association(:memberships)).to be_loaded
  end

  it "skips the query when no one is named" do
    expect(Person).not_to receive(:where)
    expect(described_class.new([ nil ]).by_id).to eq({})
  end
end
