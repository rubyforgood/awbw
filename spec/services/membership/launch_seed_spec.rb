require "rails_helper"

RSpec.describe Membership::LaunchSeed do
  let(:zero_org) { create(:organization) }
  let(:standard_org) { create(:organization) }
  let(:io) { StringIO.new }

  def run(org_ids: [ zero_org.id ], dry_run: false, **options)
    described_class.call(org_ids:, io:, dry_run:, **options)
  end

  def facilitator(person:, organization:, **attrs)
    create(:affiliation, person:, organization:, type: "facilitator", **attrs)
  end

  describe "zero-cost pass" do
    it "creates a $0 membership and $0 first invoice for an active facilitator at a zero-cost org" do
      person = create(:person)
      facilitator(person:, organization: zero_org)

      result = run

      expect(result.created_zero).to eq(1)
      expect(result.created_standard).to eq(0)

      membership = person.memberships.sole
      expect(membership.cost_cents).to eq(0)
      expect(membership.start_date).to eq(described_class::START_DATE)
      expect(membership.end_date).to eq(described_class::TERM_END)

      invoice = membership.membership_invoices.sole
      expect(invoice.cost_cents).to eq(0)
      expect(invoice.start_date).to eq(described_class::START_DATE)
      expect(invoice.end_date).to eq(described_class::TERM_END)
    end

    it "prices a person who also facilitates elsewhere at $0 of their listed org" do
      person = create(:person)
      facilitator(person:, organization: zero_org)
      facilitator(person:, organization: standard_org)

      result = run

      expect(result.created_zero).to eq(1)
      expect(result.created_standard).to eq(0)
      expect(person.memberships.sole.cost_cents).to eq(0)
      expect(result.multi_org.map(&:person)).to eq([ person ])
      expect(result.multi_org.sole.organization_ids).to match_array([ zero_org.id, standard_org.id ])
    end
  end

  describe "standard pass" do
    it "creates a standard membership and standard first invoice for everyone else" do
      person = create(:person)
      facilitator(person:, organization: standard_org)

      result = run

      expect(result.created_zero).to eq(0)
      expect(result.created_standard).to eq(1)

      membership = person.memberships.sole
      expect(membership.cost_cents).to be_nil
      expect(membership.start_date).to eq(described_class::START_DATE)
      expect(membership.membership_invoices.sole.cost_cents).to eq(Membership.annual_cost_cents)
    end
  end

  describe "eligibility" do
    it "ignores non-facilitator titles" do
      person = create(:person)
      create(:affiliation, person:, organization: zero_org, title: "Lead Facilitator")

      expect(run.created_count).to eq(0)
      expect(person.memberships).to be_empty
    end

    it "ignores ended, upcoming, and inactive affiliations" do
      ended = create(:person)
      facilitator(person: ended, organization: zero_org, end_date: Date.current - 1.day)

      upcoming = create(:person)
      facilitator(person: upcoming, organization: zero_org, start_date: Date.current + 1.day)

      inactive = create(:person)
      facilitator(person: inactive, organization: zero_org, inactive: true)

      expect(run.created_count).to eq(0)
      expect(Membership.count).to eq(0)
    end

    it "skips active facilitators without portal access and reports why" do
      no_user = create(:person, :without_user)
      unconfirmed = create(:person, :without_user)
      create(:user, :unconfirmed, person: unconfirmed)
      locked = create(:person, :without_user)
      create(:user, :locked, person: locked)
      inactive = create(:person, :without_user)
      create(:user, person: inactive, inactive: true)

      [ no_user, unconfirmed, locked, inactive ].each do |person|
        facilitator(person:, organization: zero_org)
      end

      result = run

      expect(result.created_count).to eq(0)
      expect(result.skipped_no_access).to eq(
        "no user account" => 1,
        "unconfirmed" => 1,
        "locked" => 1,
        "inactive" => 1
      )
    end
  end

  describe "existing memberships" do
    it "skips an existing unlocked membership and reports it" do
      person = create(:person)
      facilitator(person:, organization: standard_org)
      create(:membership, person:)

      expect { run }.not_to change(Membership, :count)

      result = run
      expect(result.created_count).to eq(0)
      expect(result.skipped_existing.map(&:person)).to contain_exactly(person)
      expect(result.review_fees).to be_empty
    end

    it "reports a zero-cost person whose existing membership is not $0 for fee review" do
      person = create(:person)
      facilitator(person:, organization: zero_org)
      create(:membership, person:)

      result = run

      expect(result.skipped_existing.map(&:person)).to contain_exactly(person)
      expect(result.review_fees.map(&:person)).to contain_exactly(person)
    end

    it "does not flag a zero-cost person whose existing membership is already $0" do
      person = create(:person)
      facilitator(person:, organization: zero_org)
      create(:membership, person:, cost_cents: 0)

      result = run

      expect(result.skipped_existing.map(&:person)).to contain_exactly(person)
      expect(result.review_fees).to be_empty
    end
  end

  describe "runs" do
    it "is idempotent" do
      person = create(:person)
      facilitator(person:, organization: zero_org)

      run
      expect { run }.not_to change(Membership, :count)
    end

    it "writes nothing in a dry run" do
      person = create(:person)
      facilitator(person:, organization: zero_org)

      result = nil
      expect { result = run(dry_run: true) }.not_to change(Membership, :count)
      expect(result.created_count).to eq(1)
      expect(person.memberships).to be_empty
    end

    it "stamps created_by from the actor" do
      actor = create(:user)
      person = create(:person)
      facilitator(person:, organization: zero_org)

      result = run(actor:)

      expect(result.created.sole.membership.created_by).to eq(actor)
    end

    it "requires at least one org id" do
      expect { run(org_ids: []) }.to raise_error(ArgumentError, /ORG_IDS is required/)
    end

    it "refuses unknown org ids before writing anything" do
      person = create(:person)
      facilitator(person:, organization: zero_org)

      expect { run(org_ids: [ zero_org.id, 999_999 ]) }
        .to raise_error(ArgumentError, /Unknown organization IDs: 999999/)
      expect(person.memberships).to be_empty
    end
  end
end
