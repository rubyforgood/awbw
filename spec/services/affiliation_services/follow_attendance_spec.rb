require "rails_helper"

RSpec.describe AffiliationServices::FollowAttendance do
  let(:zone) { Time.find_zone(Event::PROGRAM_ZONE) }
  let(:event) do
    create(:event, facilitator_training: true, on_demand: true,
                   start_date: zone.local(2026, 1, 1, 9), end_date: zone.local(2026, 12, 31, 17))
  end
  let(:registration) { create(:event_registration, event: event, status: "registered") }
  let(:organization) { create(:organization) }
  let(:marked_on) { Date.new(2026, 3, 3) }
  let(:year_end) { Date.new(2026, 12, 31) }

  before { travel_to(zone.local(2026, 3, 3, 12)) }
  after { travel_back }

  def mint
    AffiliationServices::CreateFromRegistration.call(
      person: registration.registrant, organization: organization, training_date: event.starts_on, event_registration: registration
    )
    registration.registrant.affiliations.facilitators.find_by!(organization: organization)
  end

  it "holds a registered person's affiliation at the training's end date, as upcoming" do
    expect(mint).to have_attributes(start_date: year_end, upcoming?: true)
  end

  it "starts it the day they're marked attended, and says why" do
    row = mint
    registration.update!(status: "attended")

    expect(row.reload).to have_attributes(start_date: marked_on, active?: true)
    expect(row.comments.map(&:topic)).to eq([ "Attendance" ])
  end

  %w[registered incomplete_attendance no_show cancelled].each do |status|
    it "returns it to the training's end date when attended becomes #{status}" do
      row = mint
      registration.update!(status: "attended")
      travel_to(zone.local(2026, 4, 9, 12))
      registration.update!(status: status)

      expect(row.reload).to have_attributes(start_date: year_end)
    end
  end

  it "starts it on the new day when marked attended again" do
    row = mint
    registration.update!(status: "attended")
    registration.update!(status: "registered")
    travel_to(zone.local(2026, 4, 9, 12))
    registration.update!(status: "attended")

    expect(row.reload.start_date).to eq(Date.new(2026, 4, 9))
  end

  it "uses the program's day when the server is already on the next one" do
    row = mint
    travel_to(zone.local(2026, 3, 3, 22))
    registration.update!(status: "attended")

    expect(row.reload.start_date).to eq(marked_on)
  end

  it "dates an affiliation created after they attended, and can take that back" do
    registration.update!(status: "attended")
    row = mint
    expect(row.start_date).to eq(marked_on)

    registration.update!(status: "registered")
    expect(row.reload.start_date).to eq(year_end)
  end

  it "keeps a start date staff set by hand" do
    row = mint
    registration.update!(status: "attended")
    row.reload.update!(start_date: Date.new(2026, 2, 1))
    registration.update!(status: "registered")

    expect(row.reload.start_date).to eq(Date.new(2026, 2, 1))
  end

  it "leaves ended, hand-entered, and already-started affiliations alone" do
    ended = mint
    ended.update!(end_date: year_end)
    by_hand = create(:affiliation, person: registration.registrant, title: "Facilitator", start_date: year_end)
    started = create(:affiliation, person: registration.registrant, title: "Facilitator",
                                   start_date: event.starts_on, event_registration: registration)
    rows = [ ended, by_hand, started ]

    expect {
      registration.update!(status: "attended")
      registration.update!(status: "registered")
    }.not_to change { rows.map { |row| row.reload.start_date } }
  end

  it "keeps the date on a transfer out, and when that transfer is undone" do
    row = mint
    registration.update!(status: "attended")
    registration.update!(status: "transferred_out")
    expect(row.reload.start_date).to eq(marked_on)

    travel_to(zone.local(2026, 4, 9, 12))
    EventRegistrationServices::RevertTransfer.call(registration: registration)
    expect(row.reload.start_date).to eq(marked_on)
  end

  it "holds a typed Facilitator job title at the training's end date" do
    AffiliationServices::CreateFromRegistration.call(
      person: registration.registrant, organization: organization, job_title: "Facilitator", event_registration: registration
    )

    expect(registration.registrant.affiliations.pluck(:title, :start_date)).to eq([ [ "Facilitator", year_end ] ])
  end

  it "doesn't re-date a live training's affiliation" do
    event.update!(on_demand: false)
    row = mint
    expect { registration.update!(status: "attended") }.not_to change { row.reload.start_date }.from(event.starts_on)
  end
end
