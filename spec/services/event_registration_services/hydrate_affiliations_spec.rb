require "rails_helper"

RSpec.describe EventRegistrationServices::HydrateAffiliations do
  let(:training_date) { Date.new(2026, 3, 12) }
  let(:event) do
    create(:event, facilitator_training: true,
                   start_date: Time.zone.local(2026, 3, 12, 9), end_date: Time.zone.local(2026, 3, 13, 16))
  end
  let(:person) { create(:person, filemaker_code: "00006") }
  let(:organization) { create(:organization, filemaker_code: "ORG00001") }
  let(:registration) { create(:event_registration, event: event, registrant: person, status: "attended") }

  def hydrate(**options)
    described_class.call(registration: registration, organization: organization, **options)
  end

  def held(title)
    person.affiliations.where(organization: organization, title: title)
  end

  describe "job affiliation" do
    it "adds one with the title, dated to the training and tied to the registration" do
      hydrate(job_title: "Counselor")

      job = held("Counselor").sole
      expect(job.start_date).to eq(training_date)
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

    it "moves a placeholder start to the training date and keeps a real one" do
      placeholder = create(:affiliation, person: person, organization: organization, title: "Counselor",
                                         start_date: Date.new(2026, 3, 1))
      real = create(:affiliation, person: person, organization: create(:organization), title: "Counselor",
                                  start_date: Date.new(2019, 5, 6))

      hydrate(job_title: "Counselor")
      described_class.call(registration: registration, organization: real.organization, job_title: "Counselor")

      expect(placeholder.reload.start_date).to eq(training_date)
      expect(real.reload.start_date).to eq(Date.new(2019, 5, 6))
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
      existing = create(:affiliation, person: person, organization: organization, start_date: Date.new(2026, 7, 1),
                                      filemaker_code: "PS1")

      hydrate

      expect(held("Facilitator").sole).to eq(existing)
      expect(existing.reload).to have_attributes(start_date: training_date, event_registration: registration,
                                                 filemaker_code: "PS1")
    end

    it "lists an ended one and leaves it ended" do
      create(:affiliation, person: person, organization: organization, start_date: Date.new(2020, 1, 1),
                           end_date: Date.new(2021, 1, 1))

      result = hydrate

      expect(held("Facilitator").count).to eq(1)
      expect(result.for_a_look.sole).to include("ended")
    end

    it "lists an active one held by someone who didn't complete" do
      registration.update!(status: "registered")
      create(:affiliation, person: person, organization: organization)

      expect(hydrate.for_a_look.sole).to include("didn't complete")
    end

    it "adds none on an event that isn't a facilitator training" do
      event.update!(facilitator_training: false)

      hydrate

      expect(held("Facilitator")).to be_empty
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
