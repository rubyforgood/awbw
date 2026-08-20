require "rails_helper"

RSpec.describe AffiliationServices::CreateFromRegistration do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  def titles
    person.affiliations.where(organization: organization).pluck(:title)
  end

  it "creates a job affiliation and a facilitator affiliation when a title is given" do
    described_class.call(person: person, organization: organization, job_title: "Counselor")

    expect(titles).to contain_exactly("Counselor", "Facilitator")
  end

  it "creates only a facilitator affiliation when no title is given" do
    described_class.call(person: person, organization: organization, job_title: nil)

    expect(titles).to contain_exactly("Facilitator")
  end

  it "treats a blank title as no title" do
    described_class.call(person: person, organization: organization, job_title: "   ")

    expect(titles).to contain_exactly("Facilitator")
  end

  describe "a non-facilitator-training event" do
    it "creates only the job affiliation, not a facilitator affiliation" do
      described_class.call(person: person, organization: organization,
                           job_title: "Counselor", facilitator_training: false)

      expect(titles).to contain_exactly("Counselor")
    end

    it "creates no affiliations when no job title is given" do
      described_class.call(person: person, organization: organization,
                           job_title: nil, facilitator_training: false)

      expect(titles).to be_empty
    end

    it "leaves an existing facilitator affiliation alone rather than ending it" do
      create(:affiliation, person: person, organization: organization, title: "Facilitator")

      described_class.call(person: person, organization: organization,
                           job_title: "Counselor", facilitator_training: false)

      expect(titles).to contain_exactly("Counselor", "Facilitator")
    end
  end

  it "still adds a Facilitator affiliation alongside a facilitator-ish job title" do
    described_class.call(person: person, organization: organization, job_title: "Lead Facilitator")

    expect(titles).to contain_exactly("Lead Facilitator", "Facilitator")
  end

  it "does not add a duplicate when the job title is exactly Facilitator" do
    described_class.call(person: person, organization: organization, job_title: "Facilitator")

    expect(titles).to contain_exactly("Facilitator")
  end

  it "skips the facilitator affiliation when an active one already exists for the org" do
    create(:affiliation, person: person, organization: organization, title: "Facilitator")

    expect {
      described_class.call(person: person, organization: organization, job_title: "Counselor")
    }.to change { titles.sort }.from(%w[Facilitator]).to(%w[Counselor Facilitator])

    expect(person.affiliations.facilitators.where(organization: organization).count).to eq(1)
  end

  it "skips the facilitator affiliation when a pending (future-dated) one already exists for the org" do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 2.months.from_now.to_date)

    described_class.call(person: person, organization: organization, job_title: nil)

    expect(person.affiliations.facilitators.where(organization: organization).count).to eq(1)
  end

  it "adds a facilitator affiliation when the existing one for the org has ended" do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", end_date: 1.month.ago.to_date)

    described_class.call(person: person, organization: organization, job_title: nil)

    expect(person.affiliations.facilitators.where(organization: organization).count).to eq(2)
  end

  it "does not create a duplicate affiliation with the same title, org, and dates" do
    described_class.call(person: person, organization: organization,
                         job_title: "Counselor", training_date: Date.new(2026, 9, 17))
    described_class.call(person: person, organization: organization,
                         job_title: "Counselor", training_date: Date.new(2026, 9, 17))

    expect(titles).to contain_exactly("Counselor", "Facilitator")
  end

  it "does not duplicate the job affiliation on a repeat call" do
    described_class.call(person: person, organization: organization, job_title: "Counselor")
    described_class.call(person: person, organization: organization, job_title: "Counselor")

    expect(titles).to contain_exactly("Counselor", "Facilitator")
  end

  it "links every created affiliation to the given organization address" do
    address = create(:address, addressable: organization)

    described_class.call(person: person, organization: organization,
                         job_title: "Counselor", organization_address: address)

    linked = person.affiliations.where(organization: organization)
    expect(linked.pluck(:title)).to contain_exactly("Counselor", "Facilitator")
    expect(linked.map(&:organization_address)).to all(eq(address))
  end

  it "leaves the organization address nil when none is given" do
    described_class.call(person: person, organization: organization, job_title: "Counselor")

    expect(person.affiliations.where(organization: organization).map(&:organization_address)).to all(be_nil)
  end

  describe "backfilling the organization address onto an affiliation that already exists" do
    let(:address) { create(:address, addressable: organization) }

    it "links the address to an existing job affiliation that has none, instead of skipping it" do
      job = create(:affiliation, person: person, organization: organization, title: "Counselor", organization_address: nil)

      described_class.call(person: person, organization: organization,
                           job_title: "Counselor", organization_address: address)

      expect(job.reload.organization_address).to eq(address)
    end

    it "links the address to an existing facilitator affiliation that has none" do
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator", organization_address: nil)

      described_class.call(person: person, organization: organization, organization_address: address)

      expect(facilitator.reload.organization_address).to eq(address)
    end

    it "does not overwrite an address the affiliation already has" do
      other = create(:address, addressable: organization)
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator", organization_address: other)

      described_class.call(person: person, organization: organization, organization_address: address)

      expect(facilitator.reload.organization_address).to eq(other)
    end

    it "leaves the existing affiliation's address nil when no address is given" do
      facilitator = create(:affiliation, person: person, organization: organization, title: "Facilitator", organization_address: nil)

      described_class.call(person: person, organization: organization)

      expect(facilitator.reload.organization_address).to be_nil
    end
  end

  describe "recording the registration that created the affiliation" do
    let(:registration) { create(:event_registration) }

    it "stamps the event_registration onto every row it creates" do
      described_class.call(person: person, organization: organization,
                           job_title: "Counselor", event_registration: registration)

      created = person.affiliations.where(organization: organization)
      expect(created.pluck(:title)).to contain_exactly("Counselor", "Facilitator")
      expect(created.map(&:event_registration)).to all(eq(registration))
    end

    it "leaves the link nil when no registration is given" do
      described_class.call(person: person, organization: organization, job_title: "Counselor")

      expect(person.affiliations.where(organization: organization).map(&:event_registration)).to all(be_nil)
    end

    it "does not stamp an existing (manual) affiliation it only backfills" do
      manual = create(:affiliation, person: person, organization: organization, title: "Facilitator")

      described_class.call(person: person, organization: organization,
                           job_title: "Counselor", event_registration: registration)

      expect(manual.reload.event_registration).to be_nil
    end
  end

  it "leaves the job affiliation without a start date" do
    described_class.call(person: person, organization: organization, job_title: "Counselor")

    job = person.affiliations.find_by(organization: organization, title: "Counselor")
    expect(job.start_date).to be_nil
  end

  it "starts the facilitator affiliation on the training date" do
    described_class.call(person: person, organization: organization,
                         job_title: "Counselor", training_date: Date.new(2026, 9, 17))

    facilitator = person.affiliations.find_by(organization: organization, title: "Facilitator")
    expect(facilitator.start_date).to eq(Date.new(2026, 9, 17))
  end

  it "falls back to today for the facilitator affiliation when no training date is given" do
    described_class.call(person: person, organization: organization, job_title: nil)

    facilitator = person.affiliations.find_by(organization: organization, title: "Facilitator")
    expect(facilitator.start_date).to eq(Date.current)
  end
end
