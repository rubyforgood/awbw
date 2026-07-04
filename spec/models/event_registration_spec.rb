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

    it "returns false for transferred_out status" do
      reg = create(:event_registration, status: "transferred_out")
      expect(reg).not_to be_active
    end

    it "returns true for transferred_in status" do
      reg = create(:event_registration, status: "transferred_in")
      expect(reg).to be_active
    end
  end

  describe ".active" do
    it "returns only registrations with active statuses" do
      active_reg = create(:event_registration, status: "registered")
      transferred_in_reg = create(:event_registration, status: "transferred_in")
      cancelled_reg = create(:event_registration, status: "cancelled")
      no_show_reg = create(:event_registration, status: "no_show")
      transferred_out_reg = create(:event_registration, status: "transferred_out")

      results = EventRegistration.active
      expect(results).to include(active_reg, transferred_in_reg)
      expect(results).not_to include(cancelled_reg, no_show_reg, transferred_out_reg)
    end
  end

  describe "#sync_attendance_status_to_days!" do
    # A two-day event: start and end one day apart → day_count == 2.
    let(:event) { create(:event, start_date: 12.days.from_now, end_date: 13.days.from_now) }
    let(:registration) { create(:event_registration, event: event, status: "registered") }

    it "flips registered → attended when all days are complete" do
      registration.update!(completed_day_1: true, completed_day_2: true)
      expect(registration.sync_attendance_status_to_days!).to be(true)
      expect(registration.reload.status).to eq("attended")
    end

    it "flips to incomplete_attendance when only some days are complete" do
      registration.update!(completed_day_1: true)
      expect(registration.sync_attendance_status_to_days!).to be(true)
      expect(registration.reload.status).to eq("incomplete_attendance")
    end

    it "rolls back to registered when no days are complete" do
      registration.update!(status: "attended", completed_day_1: false, completed_day_2: false)
      expect(registration.sync_attendance_status_to_days!).to be(true)
      expect(registration.reload.status).to eq("registered")
    end

    it "treats a one-day event as registered/attended with no partial state" do
      one_day = create(:event, start_date: 12.days.from_now, end_date: 12.days.from_now)
      reg = create(:event_registration, event: one_day, status: "registered", completed_day_1: true)
      expect(reg.sync_attendance_status_to_days!).to be(true)
      expect(reg.reload.status).to eq("attended")
    end

    it "returns false and leaves the status untouched when it already matches" do
      registration.update!(completed_day_1: true, completed_day_2: true, status: "attended")
      expect(registration.sync_attendance_status_to_days!).to be(false)
      expect(registration.reload.status).to eq("attended")
    end

    it "never overrides a deliberate inactive status (cancelled / no_show)" do
      %w[ cancelled no_show ].each do |inactive|
        reg = create(:event_registration, event: event, status: inactive, completed_day_1: true, completed_day_2: true)
        expect(reg.sync_attendance_status_to_days!).to be(false)
        expect(reg.reload.status).to eq(inactive)
      end
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

    describe ".ce_status" do
      let!(:complete_ce) do
        create(:event_registration, event: event, ce_credit_requested: true, ce_license_number: "ABC123", ce_hours_requested: 3).tap do |r|
          create(:allocation, source: create(:payment, amount_cents: event.cost_cents, amount_cents_remaining: event.cost_cents),
                              allocatable: r, amount: event.cost_cents)
        end
      end
      let!(:missing_ce) { create(:event_registration, event: event, ce_credit_requested: true) }
      let!(:no_ce) { create(:event_registration, event: event, ce_credit_requested: false) }

      it "maps 'requested' to anyone who asked for CE credit" do
        results = EventRegistration.ce_status("requested")
        expect(results).to include(complete_ce, missing_ce)
        expect(results).not_to include(no_ce)
      end

      it "maps 'license_not_provided' to CE requests missing a license number" do
        results = EventRegistration.ce_status("license_not_provided")
        expect(results).to include(missing_ce)
        expect(results).not_to include(complete_ce, no_ce)
      end

      it "maps 'hours_not_provided' to CE requests missing hours" do
        results = EventRegistration.ce_status("hours_not_provided")
        expect(results).to include(missing_ce)
        expect(results).not_to include(complete_ce, no_ce)
      end

      it "maps 'paid' to CE requests that are paid in full" do
        results = EventRegistration.ce_status("paid")
        expect(results).to include(complete_ce)
        expect(results).not_to include(missing_ce, no_ce)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.ce_status("bogus")).to include(complete_ce, missing_ce, no_ce)
      end
    end

    describe ".comment_status" do
      let!(:no_comment) { create(:event_registration, event: event) }
      let!(:commented) { create(:event_registration, event: event).tap { |r| create(:comment, commentable: r, body: "Hi") } }
      let!(:flagged) { create(:event_registration, event: event).tap { |r| create(:comment, commentable: r, body: "Flag", flagged: true) } }

      it "maps 'none' to registrations without comments" do
        results = EventRegistration.comment_status("none")
        expect(results).to include(no_comment)
        expect(results).not_to include(commented, flagged)
      end

      it "maps 'present' to registrations with any comment" do
        results = EventRegistration.comment_status("present")
        expect(results).to include(commented, flagged)
        expect(results).not_to include(no_comment)
      end

      it "maps 'flagged' to registrations with a flagged comment" do
        results = EventRegistration.comment_status("flagged")
        expect(results).to include(flagged)
        expect(results).not_to include(no_comment, commented)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.comment_status("bogus")).to include(no_comment, commented, flagged)
      end
    end

    describe ".account_status" do
      # The person factory auto-builds a confirmed user, so each case sets the
      # registrant's account state explicitly (user: nil for no account).
      let!(:none_reg) { create(:event_registration, event: event, registrant: create(:person, user: nil)) }
      let!(:access_reg) { create(:event_registration, event: event, registrant: create(:person, user: create(:user, confirmed_at: Time.current))) }
      let!(:invited_reg) { create(:event_registration, event: event, registrant: create(:person, user: create(:user, confirmed_at: nil, welcome_instructions_sent_at: Time.current))) }
      let!(:no_access_reg) { create(:event_registration, event: event, registrant: create(:person, user: create(:user, confirmed_at: nil, welcome_instructions_sent_at: nil))) }

      it "maps 'none' to registrants without an account" do
        results = EventRegistration.account_status("none")
        expect(results).to include(none_reg)
        expect(results).not_to include(access_reg, invited_reg, no_access_reg)
      end

      it "maps 'has_access' to confirmed, unlocked, active accounts" do
        results = EventRegistration.account_status("has_access")
        expect(results).to include(access_reg)
        expect(results).not_to include(none_reg, invited_reg, no_access_reg)
      end

      it "maps 'invited' to invited accounts that don't yet have access" do
        results = EventRegistration.account_status("invited")
        expect(results).to include(invited_reg)
        expect(results).not_to include(none_reg, access_reg, no_access_reg)
      end

      it "maps 'no_access' to accounts that are neither invited nor active" do
        results = EventRegistration.account_status("no_access")
        expect(results).to include(no_access_reg)
        expect(results).not_to include(none_reg, access_reg, invited_reg)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.account_status("bogus")).to include(none_reg, access_reg, invited_reg, no_access_reg)
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

  describe "#videoconference_details_visible?" do
    let(:user) { create(:user, :with_person) }

    it "is true within a week of the start for a registrant with payment access" do
      event = create(:event, cost_cents: 1099, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg.videoconference_details_visible?).to be true
    end

    it "is false more than a week before the start" do
      event = create(:event, cost_cents: 1099, start_date: 8.days.from_now, end_date: 8.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg.videoconference_details_visible?).to be false
    end

    it "is false within a week when the registrant lacks payment access" do
      event = create(:event, cost_cents: 1099, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg.videoconference_details_visible?).to be false
    end

    it "is true within a week for a free event regardless of payment" do
      event = create(:event, cost_cents: 0, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg.videoconference_details_visible?).to be true
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

  describe "registration organizations" do
    it "does not auto-connect the registrant's affiliations on create" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org)

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

  describe "#program_statuses" do
    let(:registration) { create(:event_registration) }
    let(:linked_org) { create(:organization, name: "Registration Org") }
    let(:other_org) { create(:organization, name: "Other Org") }

    it "classifies only the organization linked to the registration" do
      create(:event_registration_organization, event_registration: registration, organization: linked_org)
      # An unrelated facilitator affiliation to a different org must be ignored.
      create(:affiliation, organization: other_org, person: registration.registrant,
             title: "Facilitator", start_date: Date.current)

      expect(registration.reload.program_statuses).to eq([ :new ])
    end

    it "is ongoing when the linked org already had an active facilitator, excluding the registrant's own" do
      create(:event_registration_organization, event_registration: registration, organization: linked_org)
      create(:affiliation, organization: linked_org, title: "Facilitator",
             start_date: 2.years.ago, end_date: nil)
      create(:affiliation, organization: linked_org, person: registration.registrant,
             title: "Facilitator", start_date: Date.current)

      expect(registration.reload.program_statuses).to eq([ :ongoing ])
    end
  end

  describe "onboarding checklist" do
    let(:registration) { create(:event_registration) }
    let(:step) { EventRegistration::CHECKLIST_STEPS.keys.first }

    it "reports a step as completed once a completion row exists" do
      expect(registration.checklist_step_completed?(step)).to be(false)
      create(:event_registration_checklist_completion, event_registration: registration, step: step)
      registration.reload
      expect(registration.checklist_step_completed?(step)).to be(true)
    end

    it "exposes the completion record for a step" do
      completion = create(:event_registration_checklist_completion, event_registration: registration, step: step)
      expect(registration.reload.checklist_completion_for(step)).to eq(completion)
    end
  end

  describe "#payments_sum" do
    it "counts only payment allocations, excluding scholarship" do
      event = create(:event, cost_cents: 3_000)
      reg = create(:event_registration, event: event)
      payment = create(:payment, amount_cents: 1_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1_000)
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 1_500)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1_500)

      reg.reload
      expect(reg.payments_sum).to eq(1_000)        # payment only
      expect(reg.allocations_sum).to eq(2_500)     # payment + scholarship
    end
  end

  describe "#discount_sum" do
    it "counts only discount allocations, excluding payment and scholarship" do
      event = create(:event, cost_cents: 3_000)
      reg = create(:event_registration, event: event)
      payment = create(:payment, amount_cents: 1_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1_000)
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 1_000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1_000)
      create(:allocation, source: create(:discount, amount_cents: 800), allocatable: reg, amount: 800)

      reg.reload
      expect(reg.discount_sum).to eq(800)
    end
  end

  describe "payment reads from a preloaded allocations association" do
    it "issues no per-row queries when allocations are preloaded" do
      event = create(:event, cost_cents: 1_000)
      reg = create(:event_registration, event: event)
      payment = create(:payment, amount_cents: 1_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1_000)

      preloaded = EventRegistration.includes(:allocations, :event).find(reg.id)

      queries = []
      subscriber = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        preloaded.allocations_sum
        preloaded.payments_sum
        preloaded.discounted?
        preloaded.paid_in_full?
        preloaded.partially_paid?
      end

      expect(queries).to be_empty
      expect(preloaded.paid_in_full?).to be(true)
    end
  end
end
