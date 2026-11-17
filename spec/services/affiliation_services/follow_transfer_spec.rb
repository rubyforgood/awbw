require "rails_helper"

RSpec.describe AffiliationServices::FollowTransfer do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:source_event) { create(:event, facilitator_training: true, start_date: 1.month.from_now, end_date: 1.month.from_now + 1.day) }
  let(:destination_event) do
    create(:event, facilitator_training: true, start_date: 3.months.from_now, end_date: 3.months.from_now + 1.day,
                   registration_close_date: 2.months.from_now)
  end

  def registration_for(event, link_org: organization)
    reg = create(:event_registration, registrant: person, event: event, status: "registered")
    create(:event_registration_organization, event_registration: reg, organization: link_org) if link_org
    reg
  end

  def facilitator_row(registration: nil, start_date: source_event.starts_on, end_date: nil)
    create(:affiliation, person: person, organization: organization, title: "Facilitator",
                         start_date: start_date, end_date: end_date, event_registration: registration)
  end

  let(:source) { registration_for(source_event) }
  let(:destination) { registration_for(destination_event) }

  it "moves the open row the source created: re-dated to the destination and re-pointed at it" do
    row = facilitator_row(registration: source)

    described_class.call(to: destination, from: [ source ])

    row.reload
    expect(row.start_date).to eq(destination_event.starts_on)
    expect(row.event_registration_id).to eq(destination.id)
    expect(row.end_date).to be_nil
    expect(row.comments.last.topic).to eq(described_class::COMMENT_TOPIC)
    expect(row.comments.last.body).to include("transferred out of #{source_event.title}")
  end

  it "leaves an older or hand-entered row alone, so the years before stay on record" do
    older = facilitator_row(start_date: 5.years.ago.to_date)

    described_class.call(to: destination, from: [ source ])

    expect(older.reload.start_date).to eq(5.years.ago.to_date)
    expect(older.event_registration_id).to be_nil
  end

  it "leaves an ended row alone" do
    ended = facilitator_row(registration: source, end_date: source_event.starts_on)

    described_class.call(to: destination, from: [ source ])

    expect(ended.reload.event_registration_id).to eq(source.id)
  end

  it "moves nothing to an event that isn't a facilitator training" do
    row = facilitator_row(registration: source)
    destination_event.update!(facilitator_training: false)

    expect(described_class.call(to: destination, from: [ source ])).to eq([])
    expect(row.reload.event_registration_id).to eq(source.id)
  end

  it "moves nothing for an organization the destination doesn't link" do
    row = facilitator_row(registration: source)
    other_destination = registration_for(destination_event, link_org: create(:organization))

    described_class.call(to: other_destination, from: [ source ])

    expect(row.reload.event_registration_id).to eq(source.id)
  end

  describe "moved_only_from" do
    it "takes back only a row an earlier transfer moved there" do
      moved = facilitator_row(registration: source)
      described_class.call(to: destination, from: [ source ])

      described_class.call(to: source, moved_only_from: [ destination ], undo: true)

      moved.reload
      expect(moved.event_registration_id).to eq(source.id)
      expect(moved.start_date).to eq(source_event.starts_on)
      expect(moved.comments.reorder(:id).last.body).to include("Moved back to #{source_event.title}")
    end

    it "keeps a row the destination created for itself" do
      own = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                 start_date: destination_event.starts_on, event_registration: destination)

      described_class.call(to: source, moved_only_from: [ destination ], undo: true)

      expect(own.reload.event_registration_id).to eq(destination.id)
    end
  end
end
