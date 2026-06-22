require "rails_helper"

RSpec.describe EventRegistration, type: :model do
  subject { create(:event_registration) }

  describe "associations" do
    it { should belong_to(:event).required }
    it { should belong_to(:registrant).required }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:event_registration_organizations).dependent(:destroy) }
    it { should have_many(:organizations).through(:event_registration_organizations) }
  end

  describe "#active?" do
    it "returns true for registered status" do
      reg = create(:event_registration, status: "registered")
      expect(reg).to be_active
    end

    it "returns true for attended status" do
      reg = create(:event_registration, status: "attended")
      expect(reg).to be_active
    end

    it "returns true for incomplete_attendance status" do
      reg = create(:event_registration, status: "incomplete_attendance")
      expect(reg).to be_active
    end

    it "returns false for cancelled status" do
      reg = create(:event_registration, status: "cancelled")
      expect(reg).not_to be_active
    end

    it "returns false for no_show status" do
      reg = create(:event_registration, status: "no_show")
      expect(reg).not_to be_active
    end

    it "returns false for transferring status" do
      reg = create(:event_registration, status: "transferring")
      expect(reg).not_to be_active
    end
  end

  describe ".active" do
    it "returns only registrations with active statuses" do
      active_reg = create(:event_registration, status: "registered")
      cancelled_reg = create(:event_registration, status: "cancelled")
      no_show_reg = create(:event_registration, status: "no_show")
      transferring_reg = create(:event_registration, status: "transferring")

      results = EventRegistration.active
      expect(results).to include(active_reg)
      expect(results).not_to include(cancelled_reg, no_show_reg, transferring_reg)
    end
  end

  describe ".registrant_ids" do
    it "returns registrations for the registrants in a hyphenated id list" do
      person_a = create(:person)
      person_b = create(:person)
      person_c = create(:person)
      reg_a = create(:event_registration, registrant: person_a)
      reg_b = create(:event_registration, registrant: person_b)
      reg_c = create(:event_registration, registrant: person_c)

      results = EventRegistration.registrant_ids("#{person_a.id}-#{person_b.id}")
      expect(results).to include(reg_a, reg_b)
      expect(results).not_to include(reg_c)
    end
  end

  describe ".registrant_sector" do
    it "returns registrations whose registrant belongs to the sector" do
      sector = create(:sector)
      in_sector = create(:person)
      create(:sectorable_item, sector: sector, sectorable: in_sector)
      out_sector = create(:person)
      reg_in = create(:event_registration, registrant: in_sector)
      reg_out = create(:event_registration, registrant: out_sector)

      results = EventRegistration.registrant_sector(sector.id)
      expect(results).to include(reg_in)
      expect(results).not_to include(reg_out)
    end
  end

  describe "payment and scholarship scopes" do
    let(:event) { create(:event, cost_cents: 1000) }
    let(:paid_reg) { create(:event_registration, event: event) }
    let(:unpaid_reg) { create(:event_registration, event: event) }
    let(:scholarship_reg) { create(:event_registration, event: event) }
    let(:incomplete_scholarship_reg) { create(:event_registration, event: event) }

    before do
      create(:allocation, source: create(:payment, amount_cents: 1000, amount_cents_remaining: 1000),
                          allocatable: paid_reg, amount: 1000)
      create(:allocation, source: create(:payment, amount_cents: 400, amount_cents_remaining: 400),
                          allocatable: unpaid_reg, amount: 400)
      completed = create(:scholarship, recipient: scholarship_reg.registrant, tasks_completed: true, amount_cents: 1000)
      create(:allocation, source: completed, allocatable: scholarship_reg, amount: 1000)
      incomplete = create(:scholarship, recipient: incomplete_scholarship_reg.registrant, tasks_completed: false, amount_cents: 1000)
      create(:allocation, source: incomplete, allocatable: incomplete_scholarship_reg, amount: 0)
    end

    describe ".paid_in_full" do
      it "returns registrations whose allocations cover the cost" do
        results = EventRegistration.paid_in_full
        expect(results).to include(paid_reg, scholarship_reg)
        expect(results).not_to include(unpaid_reg)
      end
    end

    describe ".not_paid_in_full" do
      it "returns registrations still owing money" do
        results = EventRegistration.not_paid_in_full
        expect(results).to include(unpaid_reg)
        expect(results).not_to include(paid_reg, scholarship_reg)
      end
    end

    describe ".with_scholarship" do
      it "returns only registrations funded by a scholarship" do
        results = EventRegistration.with_scholarship
        expect(results).to include(scholarship_reg, incomplete_scholarship_reg)
        expect(results).not_to include(paid_reg, unpaid_reg)
      end
    end

    describe ".scholarship_tasks_completed" do
      it "returns recipients whose scholarship tasks are complete" do
        results = EventRegistration.scholarship_tasks_completed
        expect(results).to include(scholarship_reg)
        expect(results).not_to include(incomplete_scholarship_reg, paid_reg, unpaid_reg)
      end
    end

    describe ".scholarship_tasks_incomplete" do
      it "returns recipients whose scholarship tasks are not complete" do
        results = EventRegistration.scholarship_tasks_incomplete
        expect(results).to include(incomplete_scholarship_reg)
        expect(results).not_to include(scholarship_reg, paid_reg, unpaid_reg)
      end
    end

    describe ".scholarship_status" do
      it "maps 'yes' to all recipients" do
        expect(EventRegistration.scholarship_status("yes")).to include(scholarship_reg, incomplete_scholarship_reg)
        expect(EventRegistration.scholarship_status("yes")).not_to include(paid_reg, unpaid_reg)
      end

      it "maps 'complete' to completed-task recipients" do
        expect(EventRegistration.scholarship_status("complete")).to include(scholarship_reg)
        expect(EventRegistration.scholarship_status("complete")).not_to include(incomplete_scholarship_reg)
      end

      it "maps 'incomplete' to incomplete-task recipients" do
        expect(EventRegistration.scholarship_status("incomplete")).to include(incomplete_scholarship_reg)
        expect(EventRegistration.scholarship_status("incomplete")).not_to include(scholarship_reg)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.scholarship_status("bogus")).to include(scholarship_reg, incomplete_scholarship_reg, paid_reg, unpaid_reg)
      end
    end

    describe ".payment_status" do
      it "maps 'paid' to paid_in_full" do
        expect(EventRegistration.payment_status("paid")).to include(paid_reg)
        expect(EventRegistration.payment_status("paid")).not_to include(unpaid_reg)
      end

      it "maps 'unpaid' to not_paid_in_full" do
        expect(EventRegistration.payment_status("unpaid")).to include(unpaid_reg)
        expect(EventRegistration.payment_status("unpaid")).not_to include(paid_reg)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.payment_status("bogus")).to include(paid_reg, unpaid_reg)
      end
    end
  end

  describe "#scholarship?" do
    it "returns true when registration has a scholarship" do
      reg = create(:event_registration)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg).to be_scholarship
    end

    it "returns false when registration has only regular payments" do
      reg = create(:event_registration)
      payment = create(:payment, person: reg.registrant, amount_cents: 1099, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1099)
      expect(reg).not_to be_scholarship
    end

    it "returns false when registration has no scholarships" do
      reg = create(:event_registration)
      expect(reg).not_to be_scholarship
    end
  end

  describe "#registration_subject_noun" do
    it "returns the scholarship phrase when a scholarship was requested" do
      reg = create(:event_registration, scholarship_requested: true)
      expect(reg.registration_subject_noun).to eq("event scholarship registration")
    end

    it "returns the plain phrase when no scholarship was requested" do
      reg = create(:event_registration, scholarship_requested: false)
      expect(reg.registration_subject_noun).to eq("event registration")
    end
  end

  describe "#scholarship_tasks_met?" do
    it "returns true when no scholarship exists" do
      reg = create(:event_registration)
      expect(reg.scholarship_tasks_met?).to be true
    end

    it "returns false when scholarship exists but tasks not completed" do
      reg = create(:event_registration)
      scholarship = create(:scholarship, tasks_completed: false, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg.scholarship_tasks_met?).to be false
    end

    it "returns true when scholarship exists and tasks completed" do
      reg = create(:event_registration)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg.scholarship_tasks_met?).to be true
    end
  end

  describe "#joinable?" do
    let(:event) { create(:event, cost_cents: 1099, start_date: 1.hour.ago, end_date: 1.hour.from_now) }
    let(:user) { create(:user, :with_person) }

    it "returns true for active, paid, non-scholarship registration" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 1099, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1099)
      expect(reg).to be_joinable
    end

    it "returns false when not active" do
      reg = create(:event_registration, event: event, registrant: user.person, status: "cancelled")
      payment = create(:payment, person: user.person, amount_cents: 1099, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1099)
      expect(reg).not_to be_joinable
    end

    it "returns false when not paid" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg).not_to be_joinable
    end

    it "returns true for scholarship covering full cost regardless of tasks status" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: false, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg).to be_joinable
    end

    it "returns true for scholarship with tasks completed" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg).to be_joinable
    end

    it "returns true for free event with active registration" do
      free_event = create(:event, cost_cents: 0, start_date: 1.hour.ago, end_date: 1.hour.from_now)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).to be_joinable
    end

    it "returns false when the event has not entered the join window yet" do
      upcoming = create(:event, cost_cents: 0, start_date: 31.minutes.from_now, end_date: 2.hours.from_now)
      reg = create(:event_registration, event: upcoming, registrant: user.person)
      expect(reg).not_to be_joinable
    end

    it "returns false once the event's join window has closed" do
      finished = create(:event, cost_cents: 0, start_date: 2.hours.ago, end_date: 31.minutes.ago)
      reg = create(:event_registration, event: finished, registrant: user.person)
      expect(reg).not_to be_joinable
    end

    it "returns true for partial scholarship + partial payment covering full cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 500)
      create(:allocation, source: scholarship, allocatable: reg, amount: 500)
      payment = create(:payment, person: user.person, amount_cents: 599, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 599)
      expect(reg).to be_joinable
    end

    it "returns false for partial scholarship + partial payment not covering full cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 500)
      create(:allocation, source: scholarship, allocatable: reg, amount: 500)
      payment = create(:payment, person: user.person, amount_cents: 100, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 100)
      expect(reg).not_to be_joinable
    end

    it "returns true for an unpaid registration flagged intends_to_pay" do
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg).not_to be_paid_in_full
      expect(reg).to be_joinable
    end

    it "returns false for an unpaid, cancelled registration even when intends_to_pay" do
      reg = create(:event_registration, event: event, registrant: user.person, status: "cancelled", intends_to_pay: true)
      expect(reg).not_to be_joinable
    end
  end

  describe "#payment_access_granted?" do
    let(:event) { create(:event, cost_cents: 1099) }
    let(:user) { create(:user, :with_person) }

    it "is true when paid in full" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 1099, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1099)
      expect(reg.payment_access_granted?).to be true
    end

    it "is true when unpaid but flagged intends_to_pay" do
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg.payment_access_granted?).to be true
    end

    it "is false when unpaid and not flagged" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg.payment_access_granted?).to be false
    end
  end

  describe ".payment_status scope" do
    let(:event) { create(:event, cost_cents: 1099) }
    let(:user) { create(:user, :with_person) }

    it "filters to registrations flagged intends_to_pay" do
      intends = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      create(:event_registration, event: event, registrant: create(:person))
      expect(EventRegistration.payment_status("intends_to_pay")).to contain_exactly(intends)
    end
  end

  describe "#paid_in_full?" do
    let(:event) { create(:event, cost_cents: 1000) }
    let(:user) { create(:user, :with_person) }

    it "returns true when event is free" do
      free_event = create(:event, cost_cents: 0)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).to be_paid_in_full
    end

    it "returns true when scholarship allocation covers the cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 1000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1000)
      expect(reg).to be_paid_in_full
    end

    it "returns true when allocations cover cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)
      expect(reg).to be_paid_in_full
    end

    it "returns false when allocations are insufficient" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 500, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 500)
      expect(reg).not_to be_paid_in_full
    end
  end

  describe "#partially_paid?" do
    let(:event) { create(:event, cost_cents: 1000) }
    let(:user) { create(:user, :with_person) }

    it "returns false when nothing has been paid" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg).not_to be_partially_paid
    end

    it "returns true when a payment covers some but not all of the cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 500, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 500)
      expect(reg).to be_partially_paid
    end

    it "returns false when only a scholarship covers part of the cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      scholarship = create(:scholarship, tasks_completed: true, amount_cents: 500)
      create(:allocation, source: scholarship, allocatable: reg, amount: 500)
      expect(reg).not_to be_partially_paid
    end

    it "returns false when paid in full" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)
      expect(reg).not_to be_partially_paid
    end

    it "returns false when the event is free" do
      free_event = create(:event, cost_cents: 0)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).not_to be_partially_paid
    end
  end

  describe "#discounted?" do
    let(:event) { create(:event, cost_cents: 1000) }
    let(:user) { create(:user, :with_person) }

    it "returns true when a discount allocation exists" do
      reg = create(:event_registration, event: event, registrant: user.person)
      discount = Discount.create!(amount_cents: 400)
      create(:allocation, source: discount, allocatable: reg, amount: 400)
      expect(reg).to be_discounted
    end

    it "returns false when only a payment covers part of the cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      payment = create(:payment, person: user.person, amount_cents: 400, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 400)
      expect(reg).not_to be_discounted
    end
  end

  describe "continuing education" do
    let(:reg) { create(:event_registration) }

    describe "#ce_amount_owed_cents" do
      it "multiplies requested hours by the default hourly rate" do
        reg.ce_hours_requested = 4
        expect(reg.ce_amount_owed_cents).to eq(4 * EventRegistration::CE_HOURLY_RATE_DOLLARS * 100)
      end

      it "is zero when no hours are requested" do
        reg.ce_hours_requested = nil
        expect(reg.ce_amount_owed_cents).to eq(0)
      end
    end

    describe "#ce_license_provided?" do
      it "is true only when a license number is present" do
        reg.ce_license_number = "LIC-123"
        expect(reg).to be_ce_license_provided
        reg.ce_license_number = ""
        expect(reg).not_to be_ce_license_provided
      end
    end

    describe "ce_hours_requested validation" do
      it "rejects negative or non-integer hours but allows nil" do
        reg.ce_hours_requested = nil
        expect(reg).to be_valid
        reg.ce_hours_requested = -1
        expect(reg).not_to be_valid
      end
    end
  end

  describe '.search_by_params' do
    let(:person_alice) { create(:person, first_name: 'Alice', last_name: 'Smith') }
    let(:person_bob) { create(:person, first_name: 'Bob', last_name: 'Jones') }
    let(:event_art) { create(:event, title: 'Art Workshop') }
    let(:event_music) { create(:event, title: 'Music Session') }

    let!(:reg_alice_art) { create(:event_registration, registrant: person_alice, event: event_art) }
    let!(:reg_bob_music) { create(:event_registration, registrant: person_bob, event: event_music) }

    it 'returns all when no params' do
      results = EventRegistration.search_by_params({})
      expect(results).to include(reg_alice_art, reg_bob_music)
    end

    it 'filters by registrant_id' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end

    it 'filters by event_id' do
      results = EventRegistration.search_by_params(event_id: event_music.id)
      expect(results).to include(reg_bob_music)
      expect(results).not_to include(reg_alice_art)
    end

    it 'chains registrant_id and event_id filters' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id, event_id: event_art.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end

    it 'filters by organization_id via event_registration_organizations' do
      organization = create(:organization)
      create(:event_registration_organization, event_registration: reg_alice_art, organization: organization)

      results = EventRegistration.search_by_params(organization_id: organization.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end
  end

  describe "cancellation emails" do
    it "sends cancellation emails when status changes to cancelled" do
      reg = create(:event_registration, status: "registered")

      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: "event_registration_cancelled", recipient_role: :person)
      )
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: "event_registration_cancelled_fyi", recipient_role: :admin)
      )

      reg.update!(status: "cancelled")
    end

    it "does not send emails when status changes to something other than cancelled" do
      reg = create(:event_registration, status: "registered")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      reg.update!(status: "attended")
    end

    it "does not send emails when a non-status attribute changes" do
      reg = create(:event_registration, status: "cancelled")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      reg.update!(scholarship_requested: true)
    end
  end

  describe "snapshot_registrant_organizations" do
    it "copies active affiliations to the registration on create" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to include(org)
    end

    it "copies multiple active affiliations" do
      org1 = create(:organization)
      org2 = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org1)
      create(:affiliation, person: person, organization: org2)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to contain_exactly(org1, org2)
    end

    it "skips inactive affiliations" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org, inactive: true)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end

    it "skips affiliations with past end dates" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org, end_date: 1.day.ago)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end

    it "creates no records when registrant has no affiliations" do
      person = create(:person)
      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end
  end

  describe "slug" do
    it "generates a slug on create" do
      registration = create(:event_registration)
      expect(registration.slug).to be_present
      expect(registration.slug.length).to eq(22)
    end

    it "does not change slug on update" do
      registration = create(:event_registration)
      original_slug = registration.slug
      registration.update!(status: "attended")
      expect(registration.reload.slug).to eq(original_slug)
    end

    it "generates unique slugs" do
      slugs = 10.times.map { create(:event_registration).slug }
      expect(slugs.uniq.size).to eq(10)
    end
  end

  describe "#account_status" do
    def registration_for(person)
      create(:event_registration, registrant: person)
    end

    it "is none when the registrant has no user account" do
      expect(registration_for(create(:person, user: nil)).account_status).to eq("none")
    end

    it "is has_access for a confirmed, unlocked, active account" do
      expect(registration_for(create(:person)).account_status).to eq("has_access")
    end

    it "is invited when the account is pending but was sent a welcome" do
      person = create(:person)
      person.user.update!(confirmed_at: nil, welcome_instructions_sent_at: Time.current)
      expect(registration_for(person).account_status).to eq("invited")
    end

    it "is no_access when the account cannot sign in and has no pending invite" do
      person = create(:person)
      person.user.update!(confirmed_at: nil, welcome_instructions_sent_at: nil)
      expect(registration_for(person).account_status).to eq("no_access")
    end
  end
end
