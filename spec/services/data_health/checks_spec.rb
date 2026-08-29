require "rails_helper"

RSpec.describe DataHealth do
  describe ".find" do
    it "resolves a check by its key" do
      expect(described_class.find("legacy_organization_status_drift"))
        .to be_a(DataHealth::LegacyOrganizationStatusDrift)
    end

    it "is nil for an unknown key, so a bad param can't run anything" do
      expect(described_class.find("../../etc/passwd")).to be_nil
      expect(described_class.find("Affiliation")).to be_nil
    end
  end

  it "gives every check a distinct key" do
    keys = described_class.checks.map(&:key)

    expect(keys.uniq).to eq(keys)
  end

  it "keeps every check's scope a relation, so counting doesn't load the table" do
    described_class.checks.each do |check|
      expect(check.scope).to be_a(ActiveRecord::Relation), "#{check.key} returned #{check.scope.class}"
    end
  end
end

RSpec.describe DataHealth::FacilitatorAffiliationsFromNonTrainings do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }

  def affiliation_from(facilitator_training:, title: "Facilitator")
    event = create(:event, :ended, facilitator_training: facilitator_training)
    registration = create(:event_registration, event: event, registrant: person, status: "attended")
    create(:affiliation, person: person, organization: organization, title: title,
                         start_date: 1.year.ago.to_date, event_registration: registration)
  end

  it "finds a facilitator affiliation minted by a non-training registration" do
    offender = affiliation_from(facilitator_training: false)

    expect(described_class.new.scope).to include(offender)
  end

  it "leaves one minted by a real training alone" do
    affiliation_from(facilitator_training: true)

    expect(described_class.new).not_to be_any
  end

  it "ignores job affiliations — only the facilitator title confers status" do
    affiliation_from(facilitator_training: false, title: "Counselor")

    expect(described_class.new).not_to be_any
  end

  it "ignores hand-entered rows, which have no minting registration" do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 1.year.ago.to_date)

    expect(described_class.new).not_to be_any
  end

  it "deletes them and reports how many, keeping the org's status in step" do
    offender = affiliation_from(facilitator_training: false)
    check = described_class.new

    expect(check.repair!).to eq(1)
    expect(Affiliation.exists?(offender.id)).to be(false)
    expect(described_class.new).not_to be_any
  end
end

RSpec.describe DataHealth::MisalignedAffiliationProvenance do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:registration) do
    create(:event_registration, event: create(:event, :ended, facilitator_training: true),
                                registrant: person, status: "attended")
  end

  it "finds a row whose minting registration is linked to a different organization" do
    create(:event_registration_organization, event_registration: registration, organization: other_organization)
    offender = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                    start_date: 1.year.ago.to_date, event_registration: registration)

    expect(described_class.new.scope).to include(offender)
  end

  it "leaves a row whose registration is linked to its own organization" do
    create(:event_registration_organization, event_registration: registration, organization: organization)
    create(:affiliation, person: person, organization: organization, title: "Facilitator",
                         start_date: 1.year.ago.to_date, event_registration: registration)

    expect(described_class.new).not_to be_any
  end

  it "ignores hand-entered rows — a missing link is not a stale one" do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 1.year.ago.to_date)

    expect(described_class.new).not_to be_any
  end

  it "unlinks rather than deletes, so the row survives as hand-entered" do
    create(:event_registration_organization, event_registration: registration, organization: other_organization)
    offender = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                    start_date: 1.year.ago.to_date, event_registration: registration)

    expect(described_class.new.repair!).to eq(1)

    expect(offender.reload.event_registration_id).to be_nil
    expect(offender).to be_persisted
    expect(described_class.new).not_to be_any
  end
end

RSpec.describe DataHealth::LegacyOrganizationStatusDrift do
  let!(:active_status) { OrganizationStatus.find_or_create_by!(name: "Active") }
  let!(:inactive_status) { OrganizationStatus.find_or_create_by!(name: "Inactive") }

  it "finds an organization stored Active with no facilitator affiliation" do
    drifted = create(:organization, organization_status: active_status)

    expect(described_class.new.scope).to include(drifted)
  end

  it "leaves an organization whose stored status agrees with its affiliations" do
    organization = create(:organization, organization_status: active_status)
    create(:affiliation, organization: organization, title: "Facilitator",
                         start_date: 1.year.ago.to_date)

    expect(described_class.new.scope).not_to include(organization.reload)
  end

  it "reports only — there is no stored value meaning 'never active'" do
    check = described_class.new

    expect(check).not_to be_repairable
    expect { check.repair! }.to raise_error(NotImplementedError)
  end
end
