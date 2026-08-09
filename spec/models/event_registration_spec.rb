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

  describe ".registrant_name" do
    it "matches a registrant by their legal first name and last name" do
      match = create(:event_registration,
        registrant: create(:person, first_name: "Bob", legal_first_name: "Robert", last_name: "Smith"))
      other = create(:event_registration,
        registrant: create(:person, first_name: "Jane", last_name: "Doe"))

      results = EventRegistration.registrant_name("robertsmith")
      expect(results).to include(match)
      expect(results).not_to include(other)
    end
  end

  describe ".keyword" do
    it "matches a registrant by their legal first name and last name" do
      match = create(:event_registration,
        registrant: create(:person, first_name: "Bob", legal_first_name: "Robert", last_name: "Smith"))
      other = create(:event_registration,
        registrant: create(:person, first_name: "Jane", last_name: "Doe"))

      results = EventRegistration.keyword("robert smith")
      expect(results).to include(match)
      expect(results).not_to include(other)
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

  describe "#deletable?" do
    it "returns true for a plain registration with no allocations or attendance" do
      reg = create(:event_registration, status: "registered")
      expect(reg).to be_deletable
    end

    it "returns false when the registration has a payment allocation" do
      reg = create(:event_registration, status: "registered")
      payment = create(:payment, person: reg.registrant, amount_cents: 1000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 1000)
      expect(reg).not_to be_deletable
    end

    it "returns false when the registration has a scholarship allocation" do
      reg = create(:event_registration, status: "registered")
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 1000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1000)
      expect(reg).not_to be_deletable
    end

    it "returns false when the registration has an attendance outcome on record" do
      expect(create(:event_registration, status: "attended")).not_to be_deletable
      expect(create(:event_registration, status: "incomplete_attendance")).not_to be_deletable
      expect(create(:event_registration, status: "no_show")).not_to be_deletable
    end

    it "returns true for a cancelled registration with no allocations" do
      # Cancelling is a pre-event withdrawal, not an attendance outcome, so it stays deletable.
      expect(create(:event_registration, status: "cancelled")).to be_deletable
    end

    it "returns false for a transferred-out registration" do
      # The trail to the destination event is history worth keeping.
      expect(create(:event_registration, status: "transferred_out")).not_to be_deletable
    end

    it "returns true for a transferred-in registration with no allocations" do
      # Transferred-in is an ordinary active registration here; the source event's
      # transferred_out record preserves the transfer history.
      expect(create(:event_registration, status: "transferred_in")).to be_deletable
    end
  end

  describe "#cancel!" do
    it "marks the registration cancelled" do
      reg = create(:event_registration, status: "registered")
      reg.cancel!
      expect(reg.reload.status).to eq("cancelled")
    end
  end

  describe "releasing scholarships when a registration is cancelled" do
    # Returns a registered registration on a costed event with a $500 scholarship
    # awarded against it (scholarship_requested flagged, as the real award flow does).
    def registration_with_scholarship
      reg = create(:event_registration, event: create(:event, cost_cents: 50_000),
                                         status: "registered", scholarship_requested: true)
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 50_000)
      allocation = create(:allocation, source: scholarship, allocatable: reg, amount: 50_000)
      [ reg, scholarship, allocation ]
    end

    it "zeroes the scholarship award and its allocation via #cancel!" do
      reg, scholarship, allocation = registration_with_scholarship

      reg.cancel!

      expect(scholarship.reload.amount_cents).to eq(0)
      expect(allocation.reload.amount).to eq(0)
    end

    it "zeroes the scholarship on any transition to cancelled (e.g. admin edit form)" do
      reg, scholarship, _allocation = registration_with_scholarship

      reg.update!(status: "cancelled")

      expect(scholarship.reload.amount_cents).to eq(0)
    end

    it "keeps scholarship_requested set and does not re-award when reactivated" do
      reg, scholarship, _allocation = registration_with_scholarship

      reg.cancel!
      reg.update!(status: "registered")

      expect(reg.reload.scholarship_requested).to be(true)
      expect(scholarship.reload.amount_cents).to eq(0)
    end
  end

  # The attendees index composes these two rather than using one fixed scope, so
  # that the same page can also answer "no shows" and "non-trainings".
  describe ".attended composed with .event_type" do
    let!(:training) { create(:event, facilitator_training: true) }
    let!(:other) { create(:event, facilitator_training: false) }
    let!(:attended) { create(:event_registration, event: training, status: "attended") }
    let!(:no_show) { create(:event_registration, event: training, status: "no_show") }
    let!(:other_event) { create(:event_registration, event: other, status: "attended") }

    it "narrows to attended registrations on facilitator trainings" do
      results = EventRegistration.attended.event_type("trainings")
      expect(results).to include(attended)
      expect(results).not_to include(no_show, other_event)
    end

    it "reaches the rows the old fixed scope could never return" do
      expect(EventRegistration.attendance_status("no_show").event_type("trainings")).to include(no_show)
      expect(EventRegistration.attended.event_type("other")).to include(other_event)
    end

    it "passes everything through when neither is applied" do
      expect(EventRegistration.event_type(EventRegistration::FILTER_ALL))
        .to include(attended, no_show, other_event)
    end

    # Same vocabulary as the report suite's Event type filter, which forwards its
    # value straight into the attendees index.
    it "splits trainings by delivery format" do
      on_demand_training = create(:event, facilitator_training: true, on_demand: true)
      on_demand_registration = create(:event_registration, event: on_demand_training, status: "attended")

      expect(EventRegistration.event_type("live")).to include(attended)
      expect(EventRegistration.event_type("live")).not_to include(on_demand_registration, other_event)
      expect(EventRegistration.event_type("on_demand")).to include(on_demand_registration)
      expect(EventRegistration.event_type("on_demand")).not_to include(attended, other_event)
    end

    it "offers the same options the report suite's Event type filter does" do
      expect(EventRegistration::EVENT_TYPE_FILTER_OPTIONS.map(&:last))
        .to eq(%w[ trainings live on_demand other ])
    end
  end

  describe ".status_counts_by_event" do
    it "returns { event_id => { status => count } } across the given events" do
      e1 = create(:event)
      e2 = create(:event)
      create(:event_registration, event: e1, status: "attended")
      create(:event_registration, event: e1, status: "attended")
      create(:event_registration, event: e1, status: "no_show")
      create(:event_registration, event: e2, status: "registered")

      counts = EventRegistration.status_counts_by_event([ e1.id, e2.id ])
      expect(counts[e1.id]).to eq("attended" => 2, "no_show" => 1)
      expect(counts[e2.id]).to eq("registered" => 1)
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

  describe ".registrant_city" do
    it "matches registrants with an address in the city (case-insensitive, partial)" do
      in_city = create(:person)
      create(:address, addressable: in_city, city: "Santa Monica")
      out_city = create(:person)
      create(:address, addressable: out_city, city: "Portland")
      reg_in = create(:event_registration, registrant: in_city)
      reg_out = create(:event_registration, registrant: out_city)

      results = EventRegistration.registrant_city("santa")
      expect(results).to include(reg_in)
      expect(results).not_to include(reg_out)
    end
  end

  describe ".comment_text" do
    it "matches registrations whose comment topic or body contains the term" do
      reg_body = create(:event_registration)
      create(:comment, commentable: reg_body, topic: "General", body: "Needs a wheelchair ramp")
      reg_topic = create(:event_registration)
      create(:comment, commentable: reg_topic, topic: "Dietary", body: "n/a")
      reg_none = create(:event_registration)
      create(:comment, commentable: reg_none, topic: "Other", body: "nothing here")

      expect(EventRegistration.comment_text("wheelchair")).to include(reg_body)
      expect(EventRegistration.comment_text("wheelchair")).not_to include(reg_none)
      expect(EventRegistration.comment_text("dietary")).to include(reg_topic)
    end
  end

  describe ".funder_name" do
    it "matches registrations funded by a scholarship whose grant funder name matches" do
      matching_reg = create(:event_registration)
      grant = create(:grant, funder: create(:organization, name: "Big Funder Foundation"))
      scholarship = create(:scholarship, grant: grant, recipient: matching_reg.registrant)
      create(:allocation, source: scholarship, allocatable: matching_reg, amount: 0)

      other_reg = create(:event_registration)
      other = create(:scholarship, grant: create(:grant, funder: create(:organization, name: "Someone Else")),
                     recipient: other_reg.registrant)
      create(:allocation, source: other, allocatable: other_reg, amount: 0)

      results = EventRegistration.funder_name("big funder")
      expect(results).to include(matching_reg)
      expect(results).not_to include(other_reg)
    end
  end

  describe ".submission_status" do
    let(:submission_event) { create(:event) }
    let!(:none_reg) { create(:event_registration, event: submission_event) }
    let!(:single_reg) { create(:event_registration, event: submission_event) }
    let!(:multi_reg) { create(:event_registration, event: submission_event) }

    before do
      create(:form_submission, event: submission_event, person: single_reg.registrant)
      create(:form_submission, event: submission_event, person: multi_reg.registrant)
      create(:form_submission, event: submission_event, person: multi_reg.registrant)
    end

    it "finds registrants with no submission" do
      results = EventRegistration.submission_status("none", submission_event)
      expect(results).to include(none_reg)
      expect(results).not_to include(single_reg, multi_reg)
    end

    it "finds registrants with at least one submission" do
      results = EventRegistration.submission_status("has", submission_event)
      expect(results).to include(single_reg, multi_reg)
      expect(results).not_to include(none_reg)
    end

    it "finds registrants with more than one submission" do
      results = EventRegistration.submission_status("multiple", submission_event)
      expect(results).to include(multi_reg)
      expect(results).not_to include(none_reg, single_reg)
    end
  end

  describe ".scholarship_status agreed" do
    it "matches registrations with an agreement-signed scholarship" do
      agreed_reg = create(:event_registration)
      agreed = create(:scholarship, recipient: agreed_reg.registrant, agreement_signed_at: Time.current)
      create(:allocation, source: agreed, allocatable: agreed_reg, amount: 0)

      pending_reg = create(:event_registration)
      pending = create(:scholarship, recipient: pending_reg.registrant, agreement_signed_at: nil)
      create(:allocation, source: pending, allocatable: pending_reg, amount: 0)

      results = EventRegistration.scholarship_status("agreed")
      expect(results).to include(agreed_reg)
      expect(results).not_to include(pending_reg)
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

    describe ".without_scholarship" do
      it "returns only registrations with no scholarship" do
        results = EventRegistration.without_scholarship
        expect(results).to include(paid_reg, unpaid_reg)
        expect(results).not_to include(scholarship_reg, incomplete_scholarship_reg)
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

      it "maps 'no' to registrations without a scholarship" do
        expect(EventRegistration.scholarship_status("no")).to include(paid_reg, unpaid_reg)
        expect(EventRegistration.scholarship_status("no")).not_to include(scholarship_reg, incomplete_scholarship_reg)
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

    describe ".funder" do
      let(:funded_reg) { create(:event_registration, event: event) }

      before do
        funded = create(:scholarship, recipient: funded_reg.registrant, grant: create(:grant), amount_cents: 1000)
        create(:allocation, source: funded, allocatable: funded_reg, amount: 1000)
      end

      it "maps 'awbw' to recipients of grant-less (org-subsidized) scholarships" do
        results = EventRegistration.funder("awbw")
        expect(results).to include(scholarship_reg, incomplete_scholarship_reg)
        expect(results).not_to include(funded_reg, paid_reg, unpaid_reg)
      end

      it "maps 'external' to recipients of grant-funded scholarships" do
        results = EventRegistration.funder("external")
        expect(results).to include(funded_reg)
        expect(results).not_to include(scholarship_reg, incomplete_scholarship_reg, paid_reg, unpaid_reg)
      end

      it "counts a grant AWBW funded itself as org-subsidized ('awbw'), not external" do
        # Matches EventDashboard's funded/unfunded split: self-funding is subsidy.
        awbw = create(:organization, name: "A Window Between Worlds")
        self_funded_reg = create(:event_registration, event: event)
        subsidy = create(:scholarship, recipient: self_funded_reg.registrant, grant: create(:grant, funder: awbw), amount_cents: 1000)
        create(:allocation, source: subsidy, allocatable: self_funded_reg, amount: 1000)

        expect(EventRegistration.funder("awbw")).to include(self_funded_reg)
        expect(EventRegistration.funder("external")).not_to include(self_funded_reg)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.funder("bogus")).to include(funded_reg, scholarship_reg, paid_reg, unpaid_reg)
      end
    end

    describe ".ce_status" do
      let(:ce_cost) { 15_000 }
      # Known license, fully paid (certificate not yet issued).
      let!(:paid_ce) do
        create(:event_registration, event: event).tap do |r|
          cer = create(:continuing_education_registration, event_registration: r, cost_cents: ce_cost)
          create(:allocation, source: create(:payment, amount_cents: ce_cost, amount_cents_remaining: ce_cost),
                              allocatable: cer, amount: ce_cost)
        end
      end
      # Known license, unpaid.
      let!(:requested_ce) do
        create(:event_registration, event: event).tap do |r|
          create(:continuing_education_registration, event_registration: r, cost_cents: ce_cost)
        end
      end
      # CE registration sitting on a placeholder (numberless) license.
      let!(:needs_license_ce) do
        create(:event_registration, event: event).tap do |r|
          license = create(:professional_license, :placeholder, person: r.registrant)
          create(:continuing_education_registration, event_registration: r, professional_license: license, cost_cents: ce_cost)
        end
      end
      # Certificate delivered.
      let!(:issued_ce) do
        create(:event_registration, event: event).tap do |r|
          create(:continuing_education_registration, event_registration: r, cost_cents: ce_cost, certificate_sent_at: Time.current)
        end
      end
      let!(:no_ce) { create(:event_registration, event: event) }

      it "maps 'registered' to everyone signed up for CE, whatever its state" do
        results = EventRegistration.ce_status("registered")
        expect(results).to include(paid_ce, requested_ce, needs_license_ce, issued_ce)
        expect(results).not_to include(no_ce)
      end

      it "maps 'needs_license' to CE on a placeholder license" do
        results = EventRegistration.ce_status("needs_license")
        expect(results).to include(needs_license_ce)
        expect(results).not_to include(paid_ce, requested_ce, no_ce)
      end

      it "maps 'paid' to fully paid CE registrations" do
        results = EventRegistration.ce_status("paid")
        expect(results).to include(paid_ce)
        expect(results).not_to include(requested_ce, no_ce)
      end

      it "maps 'requested' to CE registrations not yet paid" do
        results = EventRegistration.ce_status("requested")
        expect(results).to include(requested_ce, needs_license_ce)
        expect(results).not_to include(paid_ce, no_ce)
      end

      it "maps 'issued' to CE registrations with a delivered certificate" do
        results = EventRegistration.ce_status("issued")
        expect(results).to include(issued_ce)
        expect(results).not_to include(requested_ce, no_ce)
      end

      it "maps 'not_issued' to CE registrations without a delivered certificate" do
        results = EventRegistration.ce_status("not_issued")
        expect(results).to include(paid_ce, requested_ce)
        expect(results).not_to include(issued_ce, no_ce)
      end

      it "maps 'none' to registrations that never signed up for CE" do
        results = EventRegistration.ce_status(EventRegistration::NO_CE)
        expect(results).to include(no_ce)
        expect(results).not_to include(paid_ce, requested_ce, needs_license_ce, issued_ce)
      end

      # The license join is an inner join, so this only holds because
      # professional_license_id is NOT NULL — every CE row has one.
      it "makes 'none' the exact complement of 'registered'" do
        all_ids = EventRegistration.where(event: event).ids
        registered = EventRegistration.where(event: event).ce_status("registered").ids
        none = EventRegistration.where(event: event).ce_status(EventRegistration::NO_CE).ids

        expect(registered & none).to be_empty
        expect((registered + none).sort).to eq(all_ids.sort)
      end

      it "returns an unfiltered relation for unknown values" do
        expect(EventRegistration.ce_status("bogus")).to include(paid_ce, requested_ce, no_ce)
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

      it "maps 'not_invited' to everyone who still needs an invite (no account or never invited)" do
        results = EventRegistration.account_status("not_invited")
        expect(results).to include(none_reg, no_access_reg)
        expect(results).not_to include(access_reg, invited_reg)
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

  describe "#scholarship_awarded?" do
    it "is false with no scholarship" do
      expect(create(:event_registration).scholarship_awarded?).to be false
    end

    it "is false while the scholarship exists but the agreement is unsigned" do
      reg = create(:event_registration)
      scholarship = create(:scholarship, amount_cents: 1099)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg.scholarship_awarded?).to be false
    end

    it "is true once the agreement is signed" do
      reg = create(:event_registration)
      scholarship = create(:scholarship, amount_cents: 1099, agreement_signed: true)
      create(:allocation, source: scholarship, allocatable: reg, amount: 1099)
      expect(reg.scholarship_awarded?).to be true
    end
  end

  describe "#joinable?" do
    # Freeze the clock so the join-window boundary cases (events placed exactly
    # 1 minute inside the 30-minute buffer) can't flake on wall-clock drift.
    before { freeze_time }

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

    it "is true for a paid registrant when the event details are ungated" do
      event = create(:event, cost_cents: 1099, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg.videoconference_details_visible?).to be true
    end

    it "is false while the event's videoconference callout drip date is still in the future" do
      event = create(:event, cost_cents: 1099, start_date: 8.days.from_now, end_date: 8.days.from_now + 2.hours)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        display_from: 2.days.from_now)
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
      expect(reg.videoconference_details_visible?).to be false
    end

    it "is false when the registrant lacks payment access, even with the event details ungated" do
      event = create(:event, cost_cents: 1099, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg.videoconference_details_visible?).to be false
    end

    it "is true for a free event regardless of payment" do
      event = create(:event, cost_cents: 0, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg.videoconference_details_visible?).to be true
    end

    it "is visible immediately once paid when the callout has no drip date" do
      event = create(:event, cost_cents: 1099, start_date: 30.days.from_now, end_date: 30.days.from_now + 2.hours)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference", display_from: nil)
      reg = create(:event_registration, event: event, registrant: user.person, intends_to_pay: true)
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

  describe ".organization_status scope" do
    let(:event) { create(:event) }

    it "filters linked / unlinked by organization link presence" do
      linked = create(:event_registration, event: event)
      create(:event_registration_organization, event_registration: linked)
      unlinked = create(:event_registration, event: event)

      expect(EventRegistration.organization_linking_status("linked", event)).to contain_exactly(linked)
      expect(EventRegistration.organization_linking_status("unlinked", event)).to contain_exactly(unlinked)
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

    def add_ce(number: "LIC-123", hours: 4, cost_cents: 15_000)
      license = create(:professional_license, person: reg.registrant, number: number)
      create(:continuing_education_registration, event_registration: reg, professional_license: license, hours: hours, cost_cents: cost_cents)
    end

    describe "#ce_amount_owed_cents" do
      it "sums the cost across the registration's CE registrations" do
        add_ce(cost_cents: 10_000)
        expect(reg.ce_amount_owed_cents).to eq(10_000)
      end

      it "is zero when no CE is requested" do
        expect(reg.ce_amount_owed_cents).to eq(0)
      end
    end

    describe "#ce_registered?" do
      it "is true only once a CE registration exists" do
        expect(reg).not_to be_ce_registered
        add_ce
        expect(reg.reload).to be_ce_registered
      end
    end

    describe "#ce_license_provided?" do
      it "is true only when every CE registration has a known license number" do
        add_ce(number: "LIC-123")
        expect(reg.reload).to be_ce_license_provided
      end

      it "is false when a CE registration sits on a placeholder license" do
        add_ce(number: nil)
        expect(reg.reload).not_to be_ce_license_provided
      end
    end

    describe "#ce_amount_due_cents" do
      it "is the cost not yet covered by payments, floored at zero" do
        cer = add_ce(cost_cents: 15_000)
        expect(reg.ce_amount_due_cents).to eq(15_000)

        payment = create(:payment, person: reg.registrant, amount_cents: 6_000, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: cer, amount: 6_000)
        expect(reg.reload.ce_amount_due_cents).to eq(9_000)
      end

      it "is zero once fully paid" do
        cer = add_ce(cost_cents: 15_000)
        payment = create(:payment, person: reg.registrant, amount_cents: 15_000, amount_cents_remaining: nil)
        create(:allocation, source: payment, allocatable: cer, amount: 15_000)
        expect(reg.reload.ce_amount_due_cents).to eq(0)
      end
    end

    describe "#ce_certificate_issued?" do
      it "is true only once every CE registration's certificate is sent" do
        cer = add_ce
        expect(reg.reload).not_to be_ce_certificate_issued
        cer.mark_certificate_sent!
        expect(reg.reload).to be_ce_certificate_issued
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

    it "counts a facilitator affiliation started earlier the same month as the training" do
      event = create(:event, start_date: Date.new(2026, 6, 20))
      reg = create(:event_registration, event: event)
      create(:event_registration_organization, event_registration: reg, organization: linked_org)
      # Earlier that same month, before the training date — still counts as ongoing.
      create(:affiliation, organization: linked_org, title: "Facilitator",
             start_date: Date.new(2026, 6, 5), end_date: nil)
      create(:affiliation, organization: linked_org, person: reg.registrant,
             title: "Facilitator", start_date: Date.new(2026, 6, 20))

      expect(reg.reload.program_statuses).to eq([ :ongoing ])
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

  describe "#receipt_available?" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:reg) { create(:event_registration, event: event) }

    it "is false for a free event" do
      free_reg = create(:event_registration, event: create(:event, cost_cents: 0))
      expect(free_reg.receipt_available?).to be(false)
    end

    it "is true once an actual payment settles the balance in full" do
      payment = create(:payment, type: "CashPayment", amount_cents: 10_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 10_000)

      expect(reg.reload.receipt_available?).to be(true)
    end

    it "is false when the balance is cleared purely by scholarship and discount" do
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 6_000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 6_000)
      create(:allocation, source: create(:discount, amount_cents: 4_000), allocatable: reg, amount: 4_000)

      expect(reg.reload.paid_in_full?).to be(true)  # balance is zero...
      expect(reg.receipt_available?).to be(false)   # ...but no money was received
    end

    it "is false while a balance remains, even with a partial payment" do
      payment = create(:payment, type: "CashPayment", amount_cents: 4_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 4_000)

      expect(reg.reload.receipt_available?).to be(false)
    end
  end

  describe "#w9_available?" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:reg) { create(:event_registration, event: event) }

    it "is true on a paid event once an actual payment is on file (cash/check)" do
      payment = create(:payment, type: "CheckPayment", amount_cents: 5_000, amount_cents_remaining: nil, check_number: "12")
      create(:allocation, source: payment, allocatable: reg, amount: 5_000)

      expect(reg.reload.w9_available?).to be(true)
    end

    it "is true for an automatic card charge too — any actual payment counts" do
      payment = create(:external_processor_payment, amount_cents: 5_000, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: reg, amount: 5_000)

      expect(reg.reload.w9_available?).to be(true)
    end

    it "is false when the balance is covered only by a scholarship or discount" do
      scholarship = create(:scholarship, recipient: reg.registrant, amount_cents: 6_000)
      create(:allocation, source: scholarship, allocatable: reg, amount: 6_000)
      create(:allocation, source: create(:discount, amount_cents: 4_000), allocatable: reg, amount: 4_000)

      expect(reg.reload.w9_available?).to be(false)
    end

    it "is false on a free event (nothing to pay)" do
      free_reg = create(:event_registration, event: create(:event, cost_cents: 0))
      expect(free_reg.w9_available?).to be(false)
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

  describe "attendance time entries" do
    let(:registration) { create(:event_registration) }

    describe "#signed_in? / #open_attendance_entry" do
      it "is signed in while today's entry has no sign-out" do
        entry = create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: Time.zone.now.change(hour: 9))
        expect(registration.signed_in?).to be(true)
        expect(registration.open_attendance_entry).to eq(entry)
      end

      it "is not signed in once every entry is closed" do
        create(:event_attendance_time_entry, event_registration: registration)
        expect(registration.signed_in?).to be(false)
        expect(registration.open_attendance_entry).to be_nil
      end

      # A forgotten sign-out must not follow the registrant into the next training
      # day, where it would block the new day's sign-in and, once closed, bank a
      # ~24-hour session. Staff close it from the attendance report instead.
      it "ignores an entry left open on an earlier day" do
        stale = create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: 1.day.ago.change(hour: 9))
        expect(registration.signed_in?).to be(false)
        expect(registration.open_attendance_entry).to be_nil
        expect(registration.open_attendance_entry(1.day.ago.to_date)).to eq(stale)
      end
    end

    describe "#attendance_entries_on" do
      it "returns that day's entries in sign-in order" do
        second = create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 11, 0), signed_out_at: Time.zone.local(2026, 7, 23, 12, 0))
        first = create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 8, 50), signed_out_at: Time.zone.local(2026, 7, 23, 10, 34))
        create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 24, 8, 50), signed_out_at: Time.zone.local(2026, 7, 24, 10, 0))

        expect(registration.attendance_entries_on(Date.new(2026, 7, 23))).to eq([ first, second ])
      end
    end

    describe "#forgotten_sign_out_entry / #forgotten_sign_out_at" do
      # A two-day training running 9:00–16:00 each day.
      let(:event) do
        create(:event, start_date: Time.zone.local(2026, 7, 23, 9, 0), end_date: Time.zone.local(2026, 7, 24, 16, 0))
      end
      let(:registration) { create(:event_registration, event: event) }

      around { |example| travel_to(Time.zone.local(2026, 7, 24, 10, 0)) { example.run } }

      it "stamps an earlier day's forgotten sign-out with that day's scheduled end" do
        stale = create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 9, 5))

        expect(registration.forgotten_sign_out_entry).to eq(stale)
        expect(registration.forgotten_sign_out_at(stale)).to eq(Time.zone.local(2026, 7, 23, 16, 0))
      end

      it "ignores today's open entry — that one is closed by the ordinary Sign out" do
        create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 24, 9, 5))

        expect(registration.forgotten_sign_out_entry).to be_nil
      end

      it "ignores earlier days that were closed properly" do
        create(:event_attendance_time_entry, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 9, 0), signed_out_at: Time.zone.local(2026, 7, 23, 16, 0))

        expect(registration.forgotten_sign_out_entry).to be_nil
      end

      # With no end time on the event there's no scheduled end to stamp, so the
      # one-click close isn't offered either.
      it "declines when the event has no end time" do
        event.update!(end_date: Time.zone.local(2026, 7, 24))
        create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 9, 5))

        expect(registration.forgotten_sign_out_entry).to be_nil
      end

      # Nothing sensible to stamp, so it isn't offered as a one-click close — staff
      # correct it on the attendance report instead.
      it "declines a sign-in recorded after that day had already ended" do
        late = create(:event_attendance_time_entry, :open, event_registration: registration,
          signed_in_at: Time.zone.local(2026, 7, 23, 18, 0))

        expect(registration.forgotten_sign_out_at(late)).to be_nil
        expect(registration.forgotten_sign_out_entry).to be_nil
      end
    end
  end
end
