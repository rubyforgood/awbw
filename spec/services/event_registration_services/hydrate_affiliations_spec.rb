require "rails_helper"

RSpec.describe EventRegistrationServices::HydrateAffiliations do
  let(:training_date) { Date.new(2026, 3, 12) }
  let(:signed_up_on) { Date.new(2026, 2, 3) }
  let(:event) do
    create(:event, facilitator_training: true,
                   start_date: Time.zone.local(2026, 3, 12, 9), end_date: Time.zone.local(2026, 3, 13, 16))
  end
  let(:person) { create(:person, filemaker_code: "00006") }
  let(:organization) { create(:organization, filemaker_code: "ORG00001") }
  let(:registration) do
    create(:event_registration, event: event, registrant: person, status: "attended",
                                created_at: Time.find_zone(Event::PROGRAM_ZONE).local(2026, 2, 3, 22))
  end

  def hydrate(**options)
    described_class.call(registration: registration, organization: organization, **options)
  end

  def held(title)
    if title == Affiliation::FACILITATOR_LABEL
      person.affiliations.facilitators.where(organization: organization)
    else
      person.affiliations.where(organization: organization, title: title)
    end
  end

  describe "job affiliation" do
    it "adds one with the title, dated to the day they signed up and tied to the registration" do
      hydrate(job_title: "Counselor")

      job = held("Counselor").sole
      expect(job.start_date).to eq(signed_up_on)
      expect(job.event_registration).to eq(registration)
    end

    it "gives an untitled one the title instead of adding a second" do
      untitled = create(:affiliation, person: person, organization: organization, title: nil)

      hydrate(job_title: "Counselor")

      expect(untitled.reload.title).to eq("Counselor")
      expect(person.affiliations.jobs.where(organization: organization).count).to eq(1)
    end

    it "leaves an existing one untied, since this training didn't create it" do
      job = create(:affiliation, person: person, organization: organization, title: "Counselor")

      hydrate(job_title: "Counselor")

      expect(job.reload.event_registration).to be_nil
    end

    it "fills a blank start with the day they signed up and keeps any other, the 1st of the month included" do
      blank = create(:affiliation, person: person, organization: organization, title: "Counselor")
      first_of_month = create(:affiliation, person: person, organization: create(:organization), title: "Counselor",
                                            start_date: Date.new(2026, 3, 1))

      hydrate(job_title: "Counselor")
      described_class.call(registration: registration, organization: first_of_month.organization, job_title: "Counselor")

      expect(blank.reload.start_date).to eq(signed_up_on)
      expect(first_of_month.reload.start_date).to eq(Date.new(2026, 3, 1))
    end

    it "lists a different title held there and leaves it" do
      create(:affiliation, person: person, organization: organization, title: "Director")

      result = hydrate(job_title: "Counselor")

      expect(held("Counselor")).to be_empty
      expect(result.for_a_look.sole).to include("Director")
    end
  end

  describe "facilitator affiliation" do
    it "adds one for someone who completed the training" do
      hydrate

      facilitator = held("Facilitator").sole
      expect(facilitator.start_date).to eq(training_date)
      expect(facilitator.event_registration).to eq(registration)
    end

    it "adds none for someone who didn't complete it" do
      registration.update!(status: "registered")

      hydrate

      expect(held("Facilitator")).to be_empty
    end

    it "ties and dates the one active one instead of adding a second, keeping its code" do
      existing = create(:affiliation, :facilitator, person: person, organization: organization,
                                      start_date: Date.new(2026, 7, 1), filemaker_code: "PS1")

      hydrate

      expect(held("Facilitator").sole).to eq(existing)
      expect(existing.reload).to have_attributes(start_date: training_date, event_registration: registration,
                                                 filemaker_code: "PS1")
    end

    it "notes what it updated in plain words" do
      create(:affiliation, :facilitator, person: person, organization: organization, start_date: Date.new(2026, 7, 1))

      expect(hydrate.changes).to eq([ "updated Facilitator affiliation: start date and tied to this registration" ])
    end

    it "keeps an ended one as history and adds a new one for this training" do
      ended = create(:affiliation, :facilitator, person: person, organization: organization,
                                   start_date: Date.new(2020, 1, 1), end_date: Date.new(2021, 1, 1))

      hydrate

      expect(ended.reload.end_date).to eq(Date.new(2021, 1, 1))
      expect(held("Facilitator").where.not(id: ended.id).sole).to have_attributes(start_date: training_date,
                                                                                event_registration: registration)
    end

    it "lists an active one held by someone who didn't complete" do
      registration.update!(status: "registered")
      create(:affiliation, :facilitator, person: person, organization: organization)

      expect(hydrate.for_a_look.sole).to include("didn't complete")
    end

    it "adds none on an event that isn't a facilitator training" do
      event.update!(facilitator_training: false)

      hydrate

      expect(held("Facilitator")).to be_empty
    end
  end

  describe "on an on-demand training" do
    let(:zone) { Time.find_zone(Event::PROGRAM_ZONE) }
    let(:event) do
      create(:event, facilitator_training: true, on_demand: true,
                     start_date: zone.local(2026, 1, 1, 9), end_date: zone.local(2026, 12, 31, 17))
    end

    before { travel_to(zone.local(2026, 3, 3, 12)) }
    after { travel_back }

    it "starts the facilitator affiliation the day it's marked attended, noted for taking attendance back" do
      hydrate

      facilitator = held("Facilitator").sole
      expect(facilitator.start_date).to eq(Date.new(2026, 3, 3))
      expect(facilitator.comments.map(&:topic)).to eq([ AffiliationServices::FollowAttendance::COMMENT_TOPIC ])
    end

    it "starts the job affiliation the day they signed up, attended or not" do
      registration.update!(status: "registered")

      hydrate(job_title: "Counselor")

      expect(held("Counselor").sole.start_date).to eq(signed_up_on)
    end

    it "keeps that start when run again on a later day" do
      hydrate
      travel_to(zone.local(2026, 4, 9, 12))

      expect { expect(hydrate.changes).to be_empty }
        .not_to(change { held("Facilitator").sole.reload.start_date })
    end
  end

  it "puts the person's FileMaker personnel codes at the organization on both, added to any already there" do
    FmProject.create!(fm_id: "P0001", data: { "OrgID" => "ORG00001" })
    FmPersonnel.create!(fm_id: "PS9001", data: { "PersonID" => "00006", "ProjectID" => "P0001" })
    FmPersonnel.create!(fm_id: "PS9002", data: { "PersonID" => "00006", "ProjectID" => "P9999" })
    job = create(:affiliation, person: person, organization: organization, title: nil, filemaker_code: "PO5")

    hydrate(job_title: "Counselor", job_title_code: "PTO7")

    expect(job.reload.filemaker_codes).to contain_exactly("PO5", "PS9001", "PTO7")
    expect(held("Facilitator").sole.filemaker_codes).to eq([ "PS9001" ])
  end

  it "changes nothing when run again" do
    hydrate(job_title: "Counselor")

    expect { expect(hydrate(job_title: "Counselor").changes).to be_empty }
      .not_to(change { person.affiliations.reload.map(&:attributes) })
  end
end
