require "rails_helper"

RSpec.describe TrainingAttendeesBreakdowns do
  let(:person) { create(:person) }
  let!(:training) { create(:event, facilitator_training: true, start_date: Date.new(2025, 5, 1)) }
  let!(:registration) { create(:event_registration, event: training, registrant: person, status: "attended") }

  # Built from a fresh relation like the controller passes it.
  subject(:breakdowns) { described_class.new(Person.where(id: person.id)) }

  it "reports the filtered person count" do
    expect(breakdowns.registrant_count).to eq(1)
  end

  it "counts distinct people per primary sector, from their profile" do
    sector = create(:sector, name: "Healthcare")
    create(:sectorable_item, sectorable: person, sector: sector, is_primary: true)
    expect(breakdowns.primary_sector_counts).to eq(sector.id => 1)
    expect(breakdowns.sector_counts).to eq(sector.id => 1)
  end

  it "counts US states from active addresses" do
    create(:address, addressable: person, state: "CA", inactive: false)
    expect(breakdowns.state_counts).to eq("CA" => 1)
  end

  it "aggregates organizations linked on the person's training registrations" do
    organization = create(:organization, name: "Wellness Org")
    registration.event_registration_organizations.create!(organization: organization)
    expect(breakdowns.organizations).to include(organization)
    expect(breakdowns.organization_counts).to eq(organization.id => 1)
  end

  it "counts scholarship recipients and CE registrants across training registrations" do
    scholarship = create(:scholarship, recipient: person, amount_cents: 1_000)
    create(:allocation, source: scholarship, allocatable: registration, amount: 1_000)
    create(:continuing_education_registration, event_registration: registration)

    expect(breakdowns.scholarship_recipient_count).to eq(1)
    expect(breakdowns.ce_registrant_ids).to eq([ person.id ])
  end
end
