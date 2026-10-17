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

  it "pages every check's rows in a stable order" do
    described_class.checks.each do |check|
      expect(check.page(1).order_values).to be_present, "#{check.key} pages without an order"
    end
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

  it "logs each unlink in the activity history" do
    create(:event_registration_organization, event_registration: registration, organization: other_organization)
    create(:affiliation, person: person, organization: organization, title: "Facilitator",
                         start_date: 1.year.ago.to_date, event_registration: registration)
    Current.user = create(:user, :admin)
    allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

    described_class.new.repair!

    expect(Analytics::LifecycleBuffer).to have_received(:push)
      .with(hash_including(name: "update.affiliation"))
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

RSpec.describe DataHealth::PeopleWithSeveralLogins do
  it "finds a person carrying two logins and links to the users deduper" do
    person = create(:person)
    create(:user, person: person)
    check = described_class.new

    expect(check.scope).to contain_exactly(person)
    expect(check.describe(person)).to include("2 logins")
    expect(check.review_path).to eq(Rails.application.routes.url_helpers.dedupe_index_users_path)
  end

  it "leaves a person with one login alone" do
    create(:person)

    expect(described_class.new).not_to be_any
  end
end

RSpec.describe DataHealth::OverAllocatedRegistrations do
  let(:event) { create(:event, cost_cents: 1_000) }
  let(:registration) { create(:event_registration, event: event) }

  # Allocation validations cap the amount at the cost, so the overage is written past them.
  def allocate(allocatable, cents)
    create(:allocation, allocatable: allocatable, amount: 0).tap { |a| a.update_column(:amount, cents) }
  end

  it "finds a registration allocated beyond its event's cost" do
    allocate(registration, 1_500)

    check = described_class.new
    expect(check.scope).to contain_exactly(registration)
    expect(check.describe(check.page(1).first)).to include("over by $5")
  end

  it "finds a registration whose CE registration is over-allocated" do
    ce = create(:continuing_education_registration, event_registration: registration, cost_cents: 2_000)
    allocate(ce, 2_500)

    expect(described_class.new.scope).to contain_exactly(registration)
  end

  it "leaves a registration paid exactly in full alone" do
    allocate(registration, 1_000)

    expect(described_class.new).not_to be_any
  end
end

RSpec.describe DataHealth::PeopleWithSeveralPrimaries do
  let(:person) { create(:person) }

  it "finds a person with two primary sectors" do
    create(:sectorable_item, sectorable: person, is_primary: true)
    item = build(:sectorable_item, sectorable: person, is_primary: true)
    item.save(validate: false)

    check = described_class.new
    expect(check.scope).to contain_exactly(person)
    expect(check.describe(person)).to include("2 primary sectors")
  end

  it "finds a person with two primary age ranges" do
    age_range = CategoryType.find_or_create_by!(name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE)
    2.times do
      create(:categorizable_item, categorizable: person, is_primary: true,
                                  category: create(:category, category_type: age_range))
    end

    expect(described_class.new.describe(person)).to include("2 primary age ranges")
  end

  it "leaves one primary and several additional alone" do
    create(:sectorable_item, sectorable: person, is_primary: true)
    create(:sectorable_item, sectorable: person, is_primary: false)

    expect(described_class.new).not_to be_any
  end
end

RSpec.describe DataHealth::StoriesWithoutWorkshop do
  it "finds a story with no workshop linked" do
    story = create(:story, workshop: nil, external_workshop_title: nil)

    expect(described_class.new.describe(story)).to include("no workshop linked")
    expect(described_class.new.scope).to include(story)
  end

  [ "Adult Windows Workshop", "Children Windows Workshop", "Children's Windows Workshop",
    "Childrens Windows Workshop", "children’s windows workshop" ].each do |placeholder|
    it "finds a story linked only to #{placeholder.inspect}" do
      story = create(:story, workshop: create(:workshop, title: placeholder))

      expect(described_class.new.scope).to include(story)
    end
  end

  it "leaves a story linked to a specific workshop alone, even alongside a placeholder" do
    story = create(:story, workshop: create(:workshop, title: "Anger Volcano"))
    create(:story_workshop, story: story, workshop: create(:workshop, title: "Adult Windows Workshop"))

    expect(described_class.new.scope).not_to include(story)
  end
end

RSpec.describe DataHealth::UnresolvedResourceAgencies do
  let!(:unknown) { OrganizationStatus.find_or_create_by!(name: "Unknown") }

  it "links a resource to the organization its agency names" do
    organization = create(:organization, name: "Lake Family Center")
    resource = create(:resource, agency: "lake family center ")

    expect(described_class.new.scope).to include(resource)
    expect(described_class.new.repair!).to eq(1)
    expect(resource.reload.organization).to eq(organization)
    expect(described_class.new).not_to be_any
  end

  it "creates the organization once when several resources share an unknown name" do
    first = create(:resource, agency: "Brand New Agency")
    second = create(:resource, agency: "brand new agency")

    expect { described_class.new.repair! }.to change(Organization, :count).by(1)
    expect(first.reload.organization).to eq(second.reload.organization)
  end

  it "can't repair without the Unknown status to give new organizations" do
    unknown.destroy

    expect(described_class.new).not_to be_repairable
  end
end

RSpec.describe DataHealth::UnboundNotifications do
  it "finds a communication with an address but no person, and reports only" do
    notification = create(:notification, person: nil, recipient_email: "nobody-#{SecureRandom.hex(4)}@example.com")

    expect(described_class.new.scope).to include(notification)
    expect(described_class.new).not_to be_repairable
  end
end

RSpec.describe DataHealth::StuckNotifications do
  def stuck(**attrs)
    create(:notification, kind: "event_registration_confirmation", created_at: 2.hours.ago, **attrs)
  end

  it "finds a portal email pending past the grace period" do
    notification = stuck

    expect(described_class.new.scope).to include(notification)
  end

  it "leaves one that has since been resent" do
    original = stuck
    create(:notification, parent_notification: original, root_notification: original)

    expect(described_class.new.scope).not_to include(original)
  end

  it "leaves delivered, failed, fresh, and Devise emails alone" do
    delivered = stuck(delivered_at: 1.hour.ago)
    failed = stuck(error_at: 1.hour.ago)
    fresh = create(:notification, kind: "event_registration_confirmation")
    devise = stuck(kind: "reset_password")

    expect(described_class.new.scope).not_to include(delivered, failed, fresh, devise)
  end
end

RSpec.describe DataHealth::Worklists do
  it "counts possible duplicates per type, with a link to each dedupe page" do
    create_list(:workshop, 2, title: "Anger Volcano")

    workshops = described_class.new.duplicates.find { |entry| entry.label == "Workshops" }

    expect(workshops.count).to eq(1)
    expect(workshops.path).to eq(Rails.application.routes.url_helpers.dedupe_index_workshops_path)
  end

  it "links each author credit count to its own section" do
    legacy = described_class.new.author_credit.find { |entry| entry.label == "Legacy name" }

    expect(legacy.path).to eq("/author_credit_divergences?section=legacy#section-legacy")
  end
end

RSpec.describe DataHealth, ".grouped_checks" do
  it "puts every check under exactly one heading" do
    grouped = described_class.grouped_checks.values.flatten.map(&:key)

    expect(grouped).to match_array(described_class.checks.map(&:key))
    expect(grouped.uniq).to eq(grouped)
  end
end
