require "rails_helper"

RSpec.describe AffiliationServices::FollowAttendance do
  let(:zone) { Time.find_zone(Event::PROGRAM_ZONE) }
  let(:on_demand) { true }
  let(:event) do
    create(:event, facilitator_training: true, on_demand: on_demand,
                   start_date: zone.local(2026, 1, 1, 9), end_date: zone.local(2026, 12, 31, 17))
  end
  let(:registration) { create(:event_registration, event: event, status: "registered") }
  let(:person) { registration.registrant }
  let(:organization) { create(:organization) }
  let(:marked_on) { Date.new(2026, 3, 3) }
  let(:year_end) { Date.new(2026, 12, 31) }

  before do
    travel_to(zone.local(2026, 3, 3, 12))
    create(:event_registration_organization, event_registration: registration, organization: organization)
  end

  after { travel_back }

  def facilitator_rows
    person.affiliations.facilitators.where(organization: organization)
  end

  def row
    facilitator_rows.sole
  end

  it "creates nothing while they're only registered" do
    AffiliationServices::CreateFromRegistration.call(
      person: person, organization: organization, job_title: "Counselor", event_registration: registration
    )

    expect(person.affiliations.pluck(:title)).to eq([ "Counselor" ])
  end

  it "creates it the day they're marked attended, and says why" do
    registration.update!(status: "attended")

    expect(row).to have_attributes(start_date: marked_on, active?: true, event_registration_id: registration.id)
    expect(row.comments.map(&:topic)).to eq([ "Attendance" ])
  end

  it "uses the program's day when the server is already on the next one" do
    travel_to(zone.local(2026, 3, 3, 22))
    registration.update!(status: "attended")

    expect(row.start_date).to eq(marked_on)
  end

  it "takes the address their job affiliation there already has" do
    address = create(:address, addressable: organization)
    AffiliationServices::CreateFromRegistration.call(
      person: person, organization: organization, job_title: "Counselor", organization_address: address,
      event_registration: registration
    )
    registration.update!(status: "attended")

    expect(row.organization_address).to eq(address)
  end

  %w[registered incomplete_attendance no_show cancelled].each do |status|
    it "removes it when attended becomes #{status}" do
      registration.update!(status: "attended")
      travel_to(zone.local(2026, 4, 9, 12))
      registration.update!(status: status)

      expect(facilitator_rows).to be_empty
    end
  end

  it "creates it on the new day when marked attended again" do
    registration.update!(status: "attended")
    registration.update!(status: "registered")
    travel_to(zone.local(2026, 4, 9, 12))
    registration.update!(status: "attended")

    expect(row.start_date).to eq(Date.new(2026, 4, 9))
  end

  it "dates a row created by linking an org after they attended, and can take that back" do
    other = create(:organization)
    registration.update!(status: "attended")
    AffiliationServices::CreateFromRegistration.call(person: person, organization: other, event_registration: registration)
    expect(person.affiliations.facilitators.find_by!(organization: other).start_date).to eq(marked_on)

    registration.update!(status: "registered")
    expect(person.affiliations.facilitators).to be_empty
  end

  it "keeps a row whose start date staff set by hand" do
    registration.update!(status: "attended")
    row.update!(start_date: Date.new(2026, 2, 1))
    registration.update!(status: "registered")

    expect(row.start_date).to eq(Date.new(2026, 2, 1))
  end

  it "adds nothing when they already have an open facilitator affiliation there" do
    by_hand = create(:affiliation, person: person, organization: organization, title: "Facilitator", start_date: 1.year.ago.to_date)

    expect { registration.update!(status: "attended") }.not_to change { facilitator_rows.count }
    registration.update!(status: "registered")
    expect(by_hand.reload).to be_active
  end

  it "keeps the row on a transfer out, and when that transfer is undone" do
    registration.update!(status: "attended")
    registration.update!(status: "transferred_out")
    expect(row.start_date).to eq(marked_on)

    travel_to(zone.local(2026, 4, 9, 12))
    EventRegistrationServices::RevertTransfer.call(registration: registration)
    expect(row.start_date).to eq(marked_on)
  end

  it "holds back a typed Facilitator job title until they attend" do
    AffiliationServices::CreateFromRegistration.call(
      person: person, organization: organization, job_title: "Facilitator", event_registration: registration
    )
    expect(person.affiliations).to be_empty

    registration.update!(status: "attended")
    expect(person.affiliations.pluck(:title, :start_date)).to eq([ [ "Facilitator", marked_on ] ])
  end

  it "moves an older on-demand row created at registration to the attended day" do
    waiting = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                   start_date: year_end, event_registration: registration)

    expect { registration.update!(status: "attended") }.not_to change { facilitator_rows.count }
    expect(waiting.reload.start_date).to eq(marked_on)
  end

  it "ignores a registration for an event that isn't a facilitator training" do
    event.update!(facilitator_training: false)

    expect { registration.update!(status: "attended") }.not_to change { facilitator_rows.count }.from(0)
  end

  context "for a live training" do
    let(:on_demand) { false }

    it "creates it dated to the training, whenever they're marked attended" do
      registration.update!(status: "attended")

      expect(row.start_date).to eq(event.starts_on)
    end

    it "removes it when attendance is taken back" do
      registration.update!(status: "attended")
      registration.update!(status: "no_show")

      expect(facilitator_rows).to be_empty
    end

    it "leaves an older row created at registration alone when attendance is taken back" do
      older = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                   start_date: event.starts_on, event_registration: registration)
      registration.update!(status: "attended")
      registration.update!(status: "no_show")

      expect(older.reload).to have_attributes(start_date: event.starts_on, end_date: nil)
    end
  end
end
