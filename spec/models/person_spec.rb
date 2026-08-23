require "rails_helper"

RSpec.describe Person, type: :model do
  describe "#membership_current?" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }

    def term(cost_cents:, start_date: Date.current, subscription: nil)
      create(:membership_invoice,
        membership: subscription || create(:membership, person: person),
        cost_cents: cost_cents,
        start_date: start_date,
        end_date: start_date + 1.year - 1.day)
    end

    it "is false with no membership at all" do
      expect(person).not_to be_membership_current
    end

    it "is true on a comped term" do
      term(cost_cents: 0, subscription: subscription)
      expect(person).to be_membership_current
    end

    it "is true on a paid term" do
      paid = term(cost_cents: 2_500, subscription: subscription)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: paid, amount: 2_500)

      expect(person).to be_membership_current
    end

    it "is true on an unpaid term still inside the grace window" do
      term(cost_cents: 2_500, start_date: Date.current - 1, subscription: subscription)
      expect(person).to be_membership_current
    end

    it "is false on an unpaid term past the grace window" do
      term(cost_cents: 2_500,
        start_date: Date.current - Membership::GRACE_PERIOD_DAYS - 1,
        subscription: subscription)

      expect(person).not_to be_membership_current
    end

    it "is false when the only comped term has expired" do
      term(cost_cents: 0, start_date: Date.current - 2.years, subscription: subscription)
      expect(person).not_to be_membership_current
    end

    it "is false when a comped term has not started yet" do
      term(cost_cents: 0, start_date: Date.current + 1.day, subscription: subscription)
      expect(person).not_to be_membership_current
    end

    it "still counts a term whose subscription was cancelled, until the term ends" do
      term(cost_cents: 0, subscription: subscription)
      subscription.update!(cancelled_at: Time.current)

      expect(person.reload).to be_membership_current
    end

    it "answers for a past date too" do
      term(cost_cents: 0, start_date: Date.current - 2.years, subscription: subscription)
      expect(person.membership_current?(as_of: Date.current - 18.months)).to be(true)
    end
  end

  describe "associations" do
    it { should have_one(:user) }
    it { should belong_to(:created_by).class_name("User").optional(true) }
    it { should belong_to(:updated_by).class_name("User").optional(true) }
    it { should have_many(:affiliations).dependent(:destroy) }
    it { should have_many(:organizations).through(:affiliations) }
    it { should have_many(:addresses) }
    it { should have_many(:contact_methods) }
    it { should have_many(:sectorable_items) }
  end

  describe "strip_whitespace" do
    let(:admin) { create(:user, :admin) }

    it "strips leading and trailing whitespace from names and emails" do
      person = create(:person, first_name: "  Jane  ", last_name: "  Doe  ",
                       email: "  jane@test.org  ", email_2: "  jane2@test.org  ",
                       created_by: admin, updated_by: admin)
      expect(person.first_name).to eq("Jane")
      expect(person.last_name).to eq("Doe")
      expect(person.email).to eq("jane@test.org")
      expect(person.email_2).to eq("jane2@test.org")
    end

    it "handles nil values" do
      person = create(:person, first_name: "Jane", last_name: "Doe",
                       email: nil, email_2: nil,
                       created_by: admin, updated_by: admin)
      expect(person.email).to be_nil
      expect(person.email_2).to be_nil
    end
  end

  describe "validations" do
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }

    it { should allow_value("test@example.com").for(:email) }
    it { should allow_value("").for(:email) }
    it { should allow_value(nil).for(:email) }
    it { should_not allow_value("not-an-email").for(:email).with_message("must be a valid email address") }

    it { should allow_value("test@example.com").for(:email_2) }
    it { should allow_value("").for(:email_2) }
    it { should_not allow_value("not-an-email").for(:email_2).with_message("must be a valid email address") }

    describe "unique_name_and_email_combination" do
      let(:admin) { create(:user, :admin) }

      it "prevents duplicate person with same name and email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:base]).to include(/already exists/)
      end

      it "is case insensitive on name" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "JANE", last_name: "DOE", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "is case insensitive on email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "Jane@Test.org",
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "allows same name with different email" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        different_email = build(:person, first_name: "Jane", last_name: "Doe", email: "other@test.org",
                                created_by: admin, updated_by: admin)
        expect(different_email).to be_valid
      end

      it "allows same email with different name" do
        create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
               created_by: admin, updated_by: admin)
        different_name = build(:person, first_name: "John", last_name: "Smith", email: "jane@test.org",
                               created_by: admin, updated_by: admin)
        expect(different_name).to be_valid
      end

      it "treats blank and nil emails as equivalent" do
        create(:person, first_name: "Jane", last_name: "Doe", email: nil,
               created_by: admin, updated_by: admin)
        duplicate = build(:person, first_name: "Jane", last_name: "Doe", email: "",
                          created_by: admin, updated_by: admin)
        expect(duplicate).not_to be_valid
      end

      it "allows updating the existing record itself" do
        person = create(:person, first_name: "Jane", last_name: "Doe", email: "jane@test.org",
                        created_by: admin, updated_by: admin)
        person.bio = "updated"
        expect(person).to be_valid
      end
    end
  end

  describe "primary sector validation (SectorsTaggable)" do
    let(:person) { build(:person) }
    let(:sector_a) { create(:sector, :published) }
    let(:sector_b) { create(:sector, :published) }

    it "is valid with no primary sectors" do
      person.sectorable_items.build(sector: sector_a, is_primary: false)
      person.sectorable_items.build(sector: sector_b, is_primary: false)
      expect(person).to be_valid
    end

    it "is valid with exactly one primary sector" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      person.sectorable_items.build(sector: sector_b, is_primary: false)
      expect(person).to be_valid
    end

    it "is invalid with more than one primary sector" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      person.sectorable_items.build(sector: sector_b, is_primary: true)
      expect(person).not_to be_valid
      expect(person.errors[:base]).to include("Only one sector can be marked as primary")
    end

    it "ignores sectorable_items marked for destruction" do
      person.sectorable_items.build(sector: sector_a, is_primary: true)
      doomed = person.sectorable_items.build(sector: sector_b, is_primary: true)
      doomed.mark_for_destruction
      expect(person).to be_valid
    end
  end

  describe "#sectorable_items_primary_first" do
    it "orders the primary sector first, then the rest alphabetically" do
      person = create(:person)
      zebra = create(:sector, :published, name: "Zebra")
      apple = create(:sector, :published, name: "Apple")
      mango = create(:sector, :published, name: "Mango")
      person.sectorable_items.create!(sector: zebra, is_primary: false)
      person.sectorable_items.create!(sector: mango, is_primary: true)
      person.sectorable_items.create!(sector: apple, is_primary: false)

      person.reload
      expect(person.sectorable_items_primary_first.map { |si| si.sector.name }).to eq(%w[Mango Apple Zebra])
    end
  end

  describe "#name" do
    let(:person) { build(:person, first_name: "Jane", last_name: "Doe") }

    context "when display_name_preference is full_name" do
      it "returns the full name" do
        person.display_name_preference = "full_name"
        expect(person.name).to eq("Jane Doe")
      end
    end

    context "when display_name_preference is first_name_last_initial" do
      it "returns first name and last initial" do
        person.display_name_preference = "first_name_last_initial"
        expect(person.name).to eq("Jane D.")
      end
    end

    context "when display_name_preference is first_name_only" do
      it "returns only the first name" do
        person.display_name_preference = "first_name_only"
        expect(person.name).to eq("Jane")
      end
    end

    context "when display_name_preference is last_name_only" do
      it "returns only the last name" do
        person.display_name_preference = "last_name_only"
        expect(person.name).to eq("Doe")
      end
    end

    context "when display_name_preference is nil or unknown" do
      it "defaults to full name" do
        person.display_name_preference = nil
        expect(person.name).to eq("Jane Doe")
      end
    end

    it "is unaffected by anonymous_contributions" do
      person.display_name_preference = "full_name"
      person.anonymous_contributions = true
      expect(person.name).to eq("Jane Doe")
    end
  end

  describe "display_name_preference validation" do
    it "accepts each allowed value" do
      Person::DISPLAY_NAME_PREFERENCES.each do |value|
        expect(build(:person, display_name_preference: value)).to be_valid
      end
    end

    it "allows blank" do
      expect(build(:person, display_name_preference: nil)).to be_valid
    end

    it "rejects anything else" do
      person = build(:person, display_name_preference: "anonymous")
      expect(person).not_to be_valid
      expect(person.errors[:display_name_preference]).to be_present
    end
  end

  describe "#effective_author_credit_preference" do
    let(:person) { build(:person, display_name_preference: "first_name_only") }

    it "is the display name preference by default" do
      expect(person.effective_author_credit_preference).to eq("first_name_only")
    end

    it "falls back to full_name when unset" do
      person.display_name_preference = nil
      expect(person.effective_author_credit_preference).to eq("full_name")
    end

    it "is anonymous when contributions are anonymous, whatever the format" do
      person.anonymous_contributions = true
      expect(person.effective_author_credit_preference).to eq("anonymous")
    end
  end

  describe "#published?" do
    let(:person) { create(:person, profile_is_searchable: true) }

    context "when person is searchable with an active affiliation" do
      before { create(:affiliation, person: person, inactive: false, end_date: nil) }

      it "returns true" do
        expect(person.published?).to be true
      end
    end

    context "when person is searchable but has no affiliations" do
      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is searchable but only has inactive affiliations" do
      before { create(:affiliation, person: person, inactive: true, end_date: nil) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is searchable but affiliation has past end date" do
      before { create(:affiliation, person: person, inactive: false, end_date: 1.day.ago) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end

    context "when person is not searchable" do
      let(:person) { create(:person, profile_is_searchable: false) }
      before { create(:affiliation, person: person, inactive: false) }

      it "returns false" do
        expect(person.published?).to be false
      end
    end
  end

  describe ".with_active_affiliations" do
    let!(:person_with_active) { create(:person) }
    let!(:person_with_inactive) { create(:person) }
    let!(:person_without) { create(:person) }

    before do
      create(:affiliation, person: person_with_active, inactive: false, end_date: nil)
      create(:affiliation, person: person_with_inactive, inactive: true, end_date: nil)
    end

    it "includes people with active affiliations" do
      expect(Person.with_active_affiliations).to include(person_with_active)
    end

    it "excludes people with only inactive affiliations" do
      expect(Person.with_active_affiliations).not_to include(person_with_inactive)
    end

    it "excludes people with no affiliations" do
      expect(Person.with_active_affiliations).not_to include(person_without)
    end
  end

  describe "#full_name" do
    it "returns first and last name" do
      person = build(:person, first_name: "Jane", last_name: "Doe")
      expect(person.full_name).to eq("Jane Doe")
    end
  end

  describe "#phone_number" do
    let(:person) { create(:person) }

    def add_phone(value, primary: false, inactive: false, kind: "phone")
      ContactMethod.create!(contactable: person, kind: kind, value: value, primary: primary, inactive: inactive)
    end

    # The same answer whether the caller preloaded contact_methods or not — the
    # loaded branch exists only to spare a query per row on rosters and exports.
    def phone_numbers
      [ person.reload.phone_number, Person.includes(:contact_methods).find(person.id).phone_number ]
    end

    it "returns nil with no phone on file" do
      add_phone("nope", kind: "sms")
      expect(phone_numbers).to all(be_nil)
    end

    it "prefers the primary phone over the others" do
      add_phone("555-0001")
      add_phone("555-0002", primary: true)
      expect(phone_numbers).to all(eq("555-0002"))
    end

    it "falls back to the first phone when none is primary" do
      add_phone("555-0001")
      add_phone("555-0002")
      expect(phone_numbers).to all(eq("555-0001"))
    end

    it "ignores inactive phones, including an inactive primary" do
      add_phone("555-0001", primary: true, inactive: true)
      add_phone("555-0002")
      expect(phone_numbers).to all(eq("555-0002"))
    end
  end

  describe "#primary_organization" do
    let(:person) { create(:person) }

    it "returns the most recently updated active organization" do
      org1 = create(:organization)
      org2 = create(:organization)
      create(:affiliation, person: person, organization: org1, inactive: false, end_date: nil, updated_at: 1.day.ago)
      create(:affiliation, person: person, organization: org2, inactive: false, end_date: nil, updated_at: Time.current)
      expect(person.primary_organization).to eq(org2)
    end

    it "returns nil when no active affiliations exist" do
      create(:affiliation, person: person, inactive: true)
      expect(person.primary_organization).to be_nil
    end

    it "returns nil when person has no affiliations" do
      expect(person.primary_organization).to be_nil
    end
  end

  describe "user association" do
    it "links to a user" do
      person = create(:person)
      expect(person.user).to be_a(User)
    end

    it "can exist without a user" do
      admin = create(:user, :admin)
      person = Person.create!(first_name: "Solo", last_name: "Person",
                              created_by: admin, updated_by: admin)
      expect(person.user).to be_nil
    end
  end

  describe '.search_by_params' do
    let(:org_alpha) { create(:organization, name: "Alpha Center") }
    let(:org_beta) { create(:organization, name: "Beta Foundation") }

    let!(:person_alice) do
      create(:person, first_name: 'Alice', last_name: 'Smith', email: 'alice@example.com').tap do |p|
        create(:affiliation, person: p, organization: org_alpha)
      end
    end

    let!(:person_bob) do
      create(:person, first_name: 'Bob', last_name: 'Jones', email: 'bob@example.com').tap do |p|
        create(:affiliation, person: p, organization: org_beta)
      end
    end

    it 'returns all when no params' do
      results = Person.search_by_params({})
      expect(results).to include(person_alice, person_bob)
    end

    it 'filters by contact_info matching name' do
      results = Person.search_by_params(contact_info: 'Alice')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'filters by contact_info matching legal first name' do
      person_carol = create(:person, first_name: 'Carol', legal_first_name: 'Caroline', last_name: 'White')

      results = Person.search_by_params(contact_info: 'Caroline')
      expect(results).to include(person_carol)
      expect(results).not_to include(person_alice, person_bob)
    end

    it 'filters by contact_info matching email' do
      results = Person.search_by_params(contact_info: 'bob@example')
      expect(results).to include(person_bob)
      expect(results).not_to include(person_alice)
    end

    it 'filters by organization_name' do
      results = Person.search_by_params(organization_name: 'Alpha')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'chains contact_info and organization_name' do
      results = Person.search_by_params(contact_info: 'Alice', organization_name: 'Alpha')
      expect(results).to include(person_alice)
      expect(results).not_to include(person_bob)
    end

    it 'chains with_active_affiliations and organization_name without an ambiguous end_date error' do
      expect {
        Person.with_active_affiliations.search_by_params(organization_name: 'Alpha').to_a
      }.not_to raise_error
    end

    context "role: sector_leader" do
      let(:sector) { create(:sector) }

      before do
        person_alice.sectorable_items.create!(sector: sector, is_leader: true)
        person_bob.sectorable_items.create!(sector: sector, is_leader: false)
      end

      it "returns only people who lead a sector" do
        results = Person.search_by_params(role: "sector_leader")
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end

      it "returns a person once even when they lead several sectors" do
        person_alice.sectorable_items.create!(sector: create(:sector), is_leader: true)
        results = Person.search_by_params(role: "sector_leader")
        expect(results.to_a.count(person_alice)).to eq(1)
      end

      it "ignores the filter when role is blank" do
        results = Person.search_by_params(role: "")
        expect(results).to include(person_alice, person_bob)
      end
    end

    context "role: story_author" do
      it "returns only people who authored a story" do
        create(:story, author: person_alice)
        results = Person.search_by_params(role: "story_author")
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end
    end

    context "role: blog_contributor" do
      it "returns only people flagged as blog contributors" do
        person_bob.update!(blog_contributor: true)
        results = Person.search_by_params(role: "blog_contributor")
        expect(results).to include(person_bob)
        expect(results).not_to include(person_alice)
      end
    end

    context "role: workshop_author" do
      it "returns only people who authored a workshop" do
        create(:workshop, author: person_alice)
        results = Person.search_by_params(role: "workshop_author")
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end
    end

    context "role: workshop_variation_author" do
      it "returns only people who authored a workshop variation" do
        create(:workshop_variation, author: person_bob)
        results = Person.search_by_params(role: "workshop_variation_author")
        expect(results).to include(person_bob)
        expect(results).not_to include(person_alice)
      end

      it "credits the submitter on a variation that names no author" do
        create(:workshop_variation, author: nil, created_by: create(:user, person: person_bob))

        results = Person.search_by_params(role: "workshop_variation_author")

        expect(results).to include(person_bob)
        expect(results).not_to include(person_alice)
      end
    end

    context "role: workshop_log_author" do
      it "returns only people credited as a workshop log author" do
        create(:workshop_log, author: person_alice)
        results = Person.search_by_params(role: "workshop_log_author")
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end

      it "matches the credited author, not whoever logged it" do
        logger = create(:user, person: person_bob)
        create(:workshop_log, created_by: logger, author: person_alice)

        results = Person.search_by_params(role: "workshop_log_author")

        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end

      it "credits the logger on a log that names no author (predates author_id)" do
        create(:workshop_log, created_by: create(:user, person: person_bob), author: nil)

        results = Person.search_by_params(role: "workshop_log_author")

        expect(results).to include(person_bob)
        expect(results).not_to include(person_alice)
      end

      it "ignores logs with neither an author nor a person behind the account" do
        create(:workshop_log, author: nil, created_by: create(:user, person: nil))
        results = Person.search_by_params(role: "workshop_log_author")
        expect(results).not_to include(person_alice, person_bob)
      end
    end

    context "membership_status" do
      it "active: includes people with a non-cancelled membership" do
        member = create(:person, first_name: "Member", last_name: "Active")
        create(:membership, person: member)
        results = Person.search_by_params(membership_status: "active")
        expect(results).to include(member)
        expect(results).not_to include(person_alice)
      end

      it "inactive: includes people whose only membership is cancelled" do
        former = create(:person, first_name: "Former", last_name: "Member")
        create(:membership, :cancelled, person: former)
        results = Person.search_by_params(membership_status: "inactive")
        expect(results).to include(former)
        expect(results).not_to include(person_alice)
      end

      it "paid: includes people with a covered current invoice" do
        member = create(:person, first_name: "Paid", last_name: "Member")
        create(:membership_invoice, :comped, membership: create(:membership, person: member))
        results = Person.search_by_params(membership_status: "paid")
        expect(results).to include(member)
      end

      it "due: includes people owing on a current invoice still within grace" do
        member = create(:person, first_name: "Due", last_name: "Member")
        create(:membership_invoice, membership: create(:membership, person: member),
                                    start_date: Date.current)
        results = Person.search_by_params(membership_status: "due")
        expect(results).to include(member)
      end

      it "overdue: includes people owing past the grace period" do
        member = create(:person, first_name: "Overdue", last_name: "Member")
        create(:membership_invoice, membership: create(:membership, person: member),
                                    start_date: 60.days.ago, end_date: 305.days.from_now)
        results = Person.search_by_params(membership_status: "overdue")
        expect(results).to include(member)
      end
    end

    context "facilitator_status" do
      # person_alice and person_bob each already have one active facilitator affiliation.

      it "active: includes people with a currently-active facilitator affiliation" do
        results = Person.search_by_params(facilitator_status: "active")
        expect(results).to include(person_alice, person_bob)
      end

      it "active: excludes people whose only facilitator affiliation starts in the future" do
        upcoming = create(:person, first_name: "Upcoming", last_name: "Fac")
        create(:affiliation, person: upcoming, title: "Facilitator", start_date: 1.month.from_now, end_date: nil)

        results = Person.search_by_params(facilitator_status: "active")
        expect(results).not_to include(upcoming)
      end

      it "upcoming: includes people whose facilitator affiliation has not yet started" do
        upcoming = create(:person, first_name: "Upcoming", last_name: "Fac")
        create(:affiliation, person: upcoming, title: "Facilitator", start_date: 1.month.from_now, end_date: nil)

        results = Person.search_by_params(facilitator_status: "upcoming")
        expect(results).to include(upcoming)
        expect(results).not_to include(person_alice)
      end

      it "inactive: includes people whose facilitator affiliations are all inactive" do
        lapsed = create(:person, first_name: "Lapsed", last_name: "Fac")
        create(:affiliation, person: lapsed, title: "Facilitator", end_date: 1.year.ago)

        results = Person.search_by_params(facilitator_status: "inactive")
        expect(results).to include(lapsed)
        expect(results).not_to include(person_alice)
      end

      it "inactive: includes an upcoming (not-yet-started) facilitator — the not-active umbrella" do
        upcoming = create(:person, first_name: "Upcoming", last_name: "Fac")
        create(:affiliation, person: upcoming, title: "Facilitator", start_date: 1.month.from_now, end_date: nil)

        results = Person.search_by_params(facilitator_status: "inactive")
        expect(results).to include(upcoming)
      end

      it "boomerang: includes people whose active term began after an earlier term ended" do
        returnee = create(:person, first_name: "Returnee", last_name: "Fac")
        create(:affiliation, person: returnee, title: "Facilitator",
                             start_date: 5.years.ago, end_date: 3.years.ago)
        create(:affiliation, person: returnee, title: "Facilitator",
                             start_date: 1.year.ago, end_date: nil)

        results = Person.search_by_params(facilitator_status: "boomerang")
        expect(results).to include(returnee)
        expect(results).not_to include(person_alice)
      end

      it "boomerang: excludes people serving two orgs concurrently who never left" do
        concurrent = create(:person, first_name: "Concurrent", last_name: "Fac")
        create(:affiliation, person: concurrent, title: "Facilitator",
                             start_date: 5.years.ago, end_date: nil)
        create(:affiliation, person: concurrent, title: "Facilitator",
                             start_date: 1.year.ago, end_date: nil)

        results = Person.search_by_params(facilitator_status: "boomerang")
        expect(results).not_to include(concurrent)
      end

      it "boomerang: excludes a continuous term overlapping a since-ended second org" do
        overlapper = create(:person, first_name: "Overlap", last_name: "Fac")
        create(:affiliation, person: overlapper, title: "Facilitator",
                             start_date: 5.years.ago, end_date: nil)
        create(:affiliation, person: overlapper, title: "Facilitator",
                             start_date: 3.years.ago, end_date: 1.year.ago)

        results = Person.search_by_params(facilitator_status: "boomerang")
        expect(results).not_to include(overlapper)
      end

      it "formerly_active: includes people whose facilitator term ended and none is active" do
        former = create(:person, first_name: "Former", last_name: "Fac")
        create(:affiliation, person: former, title: "Facilitator", end_date: 1.year.ago)

        results = Person.search_by_params(facilitator_status: "formerly_active")
        expect(results).to include(former)
        expect(results).not_to include(person_alice)
      end
    end

    context "topic_subscription_type_id" do
      let(:topic) { create(:topic_subscription_type) }

      it "returns people with an active subscription to the topic" do
        create(:topic_subscription, person: person_alice, topic_subscription_type: topic)
        results = Person.search_by_params(topic_subscription_type_id: topic.id)
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end

      it "excludes people whose subscription to the topic is unsubscribed" do
        create(:topic_subscription, :unsubscribed, person: person_bob, topic_subscription_type: topic)
        results = Person.search_by_params(topic_subscription_type_id: topic.id)
        expect(results).not_to include(person_bob)
      end
    end

    context "age_range_names_all" do
      let(:age_type) { create(:category_type, name: "AgeRange", published: true) }
      let(:teens) { create(:category, :published, name: "Teens", category_type: age_type) }
      let(:seniors) { create(:category, :published, name: "Seniors", category_type: age_type) }

      it "returns only people tagged with the named age range" do
        person_alice.categorizable_items.create!(category: teens)
        person_bob.categorizable_items.create!(category: seniors)

        results = Person.search_by_params(age_range_names_all: "Teens")
        expect(results).to include(person_alice)
        expect(results).not_to include(person_bob)
      end

      it "does not match a same-named category from another category type" do
        other_type = create(:category_type, name: "Setting", published: true)
        other_teens = create(:category, :published, name: "Teens", category_type: other_type)
        person_bob.categorizable_items.create!(category: other_teens)

        results = Person.search_by_params(age_range_names_all: "Teens")
        expect(results).not_to include(person_bob)
      end
    end
  end

  describe ".published" do
    let!(:searchable_with_active) do
      person = create(:person, profile_is_searchable: true)
      create(:affiliation, person: person, inactive: false, end_date: nil)
      person
    end

    let!(:searchable_without_active) do
      create(:person, profile_is_searchable: true)
    end

    let!(:not_searchable_with_active) do
      person = create(:person, profile_is_searchable: false)
      create(:affiliation, person: person, inactive: false, end_date: nil)
      person
    end

    it "includes searchable people with active affiliations" do
      expect(Person.published).to include(searchable_with_active)
    end

    it "excludes searchable people without active affiliations" do
      expect(Person.published).not_to include(searchable_without_active)
    end

    it "excludes non-searchable people even with active affiliations" do
      expect(Person.published).not_to include(not_searchable_with_active)
    end
  end

  describe "Other form responses" do
    let(:person) { create(:person) }
    let(:form) { create(:form) }
    let(:submission) { create(:form_submission, person: person, form: form) }

    def answer(identifier, value)
      field = create(:form_field, form: form, field_identifier: identifier)
      create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
    end

    describe "#other_sector_responses" do
      it "returns the person's visible sector OtherResponses" do
        create(:other_response, owner: person, kind: "sector", text: "Equine therapy")
        create(:other_response, :kept, owner: person, kind: "sector", text: "Music therapy")

        expect(person.other_sector_responses.map(&:text))
          .to contain_exactly("Equine therapy", "Music therapy")
      end

      it "omits dismissed and promoted responses" do
        create(:other_response, :dismissed, owner: person, kind: "sector", text: "Hidden")
        create(:other_response, :promoted, owner: person, kind: "sector", text: "Promoted")

        expect(person.other_sector_responses).to be_empty
      end
    end

    describe "#other_workshop_setting_responses" do
      it "returns free-text Other values from the category-backed fields" do
        answer("primary_age_group", "3, Other: Toddlers")

        expect(person.other_workshop_setting_responses)
          .to contain_exactly("Toddlers")
      end

      it "does not pull from the sector fields" do
        answer("additional_sectors", "Other: Equine therapy")

        expect(person.other_workshop_setting_responses).to be_empty
      end
    end
  end
end

RSpec.describe Person, "scholarship index helpers" do
  let(:person) { create(:person) }

  describe "#program_organization" do
    it "returns the organization on the recipient's facilitator affiliation" do
      org = create(:organization, name: "Prevail")
      create(:affiliation, person: person, organization: org, title: "Facilitator")

      expect(person.program_organization).to eq(org)
    end

    it "prefers an active facilitator affiliation over a lapsed one" do
      lapsed_org = create(:organization, name: "Old Program")
      active_org = create(:organization, name: "Current Program")
      create(:affiliation, person: person, organization: lapsed_org, title: "Facilitator", end_date: 1.year.ago.to_date)
      create(:affiliation, person: person, organization: active_org, title: "Facilitator")

      expect(person.program_organization).to eq(active_org)
    end

    it "ignores non-facilitator affiliations" do
      create(:affiliation, person: person, organization: create(:organization), title: "Board Member")

      expect(person.program_organization).to be_nil
    end
  end

  describe "#completed_facilitator_trainings" do
    it "returns only attended facilitator-training events" do
      training = create(:event, title: "TAC251", facilitator_training: true)
      other_training = create(:event, title: "TAC252", facilitator_training: true)
      non_training = create(:event, title: "Webinar", facilitator_training: false)
      create(:event_registration, registrant: person, event: training, status: "attended")
      create(:event_registration, registrant: person, event: other_training, status: "registered")
      create(:event_registration, registrant: person, event: non_training, status: "attended")

      expect(person.completed_facilitator_trainings).to contain_exactly(training)
    end
  end

  describe "#communications_scope" do
    it "includes communications to any of the person's addresses (login, email, email_2)" do
      person = create(:person, email: "primary@example.com", email_2: "secondary@example.com")
      to_login = create(:notification, recipient_email: person.user.email)
      to_primary = create(:notification, recipient_email: "primary@example.com")
      to_secondary = create(:notification, recipient_email: "secondary@example.com")
      create(:notification, recipient_email: "unrelated@example.com")

      expect(person.communications_scope).to contain_exactly(to_login, to_primary, to_secondary)
    end

    it "returns none when the person has no addresses on file" do
      person = create(:person, user: nil, email: nil, email_2: nil)
      create(:notification, recipient_email: "someone@example.com")

      expect(person.communications_scope).to be_empty
    end
  end
end
