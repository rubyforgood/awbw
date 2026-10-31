require "rails_helper"

RSpec.describe ContinuingEducationRegistration, type: :model do
  describe "comments" do
    it "is commentable and destroys its comments when removed" do
      ce_reg = create(:continuing_education_registration)
      comment = create(:comment, commentable: ce_reg)

      expect(ce_reg.comments).to include(comment)
      expect { ce_reg.destroy }.to change(Comment, :count).by(-1)
    end
  end

  describe "#registrant" do
    it "is its event registration's registrant" do
      ce = create(:continuing_education_registration)

      expect(ce.registrant).to eq(ce.event_registration.registrant)
    end
  end

  describe "#payment_access_granted?" do
    let(:ce) { create(:continuing_education_registration, cost_cents: 15_000) }

    it "is false while the balance is due" do
      expect(ce.payment_access_granted?).to be(false)
    end

    it "is true when it intends to pay, while the status still reads Due" do
      ce.update!(intends_to_pay: true)

      expect(ce.payment_access_granted?).to be(true)
      expect(ce.payment_status_label).to eq("Due")
    end
  end

  describe "#access_granted?" do
    let(:ce) { create(:continuing_education_registration, cost_cents: 15_000) }

    it "opens once paid, approved by default" do
      create(:allocation, source: create(:payment), allocatable: ce, amount: 15_000)
      expect(ce.access_granted?).to be(true)
    end

    it "stays closed while neither paid nor intending to pay" do
      expect(ce.access_granted?).to be(false)
    end

    it "closes when an admin denies the CE, paid or not" do
      ce.update!(intends_to_pay: true, denied_at: Time.current)
      expect(ce.access_granted?).to be(false)
    end
  end

  describe ".search_by_params approval filter" do
    let!(:approved) { create(:continuing_education_registration) }
    let!(:denied) { create(:continuing_education_registration, :denied) }

    it "narrows to approved or denied CE" do
      expect(described_class.search_by_params(approval: "approved")).to contain_exactly(approved)
      expect(described_class.search_by_params(approval: "denied")).to contain_exactly(denied)
    end
  end

  describe "validations" do
    it "rejects a license that belongs to someone other than the registrant" do
      registration = create(:event_registration)
      other_license = create(:professional_license)

      ce_reg = build(:continuing_education_registration,
        event_registration: registration, professional_license: other_license)

      expect(ce_reg).not_to be_valid
      expect(ce_reg.errors[:professional_license]).to include("must belong to the registrant")
    end

    describe "one CE registration per license on a registration" do
      let(:registration) { create(:event_registration) }
      let(:license) { create(:professional_license, person: registration.registrant) }

      before { create(:continuing_education_registration, event_registration: registration, professional_license: license) }

      it "rejects a second CE registration for the same license" do
        duplicate = build(:continuing_education_registration, event_registration: registration, professional_license: license)

        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:professional_license]).to include("already has CE on this registration")
      end

      it "allows CE for another of the registrant's licenses" do
        second_license = create(:professional_license, person: registration.registrant, kind: "LMFT", number: "77777")

        expect(build(:continuing_education_registration, event_registration: registration, professional_license: second_license)).to be_valid
      end
    end

    describe "cost_not_below_allocations" do
      it "allows setting cost above allocations" do
        ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
        payment = create(:payment, amount_cents: 3_000, amount_cents_remaining: 3_000)
        create(:allocation, source: payment, allocatable: ce_reg, amount: 3_000)

        ce_reg.cost_cents = 5_000
        expect(ce_reg).to be_valid
      end

      it "allows setting cost equal to allocations" do
        ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
        payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        create(:allocation, source: payment, allocatable: ce_reg, amount: 5_000)

        ce_reg.cost_cents = 5_000
        expect(ce_reg).to be_valid
      end

      it "rejects setting cost below allocations" do
        ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
        payment = create(:payment, amount_cents: 5_000, amount_cents_remaining: 5_000)
        create(:allocation, source: payment, allocatable: ce_reg, amount: 5_000)

        ce_reg.cost_cents = 3_000
        expect(ce_reg).not_to be_valid
        expect(ce_reg.errors[:cost_cents]).to include("can't be less than the amount already allocated ($50)")
      end

      it "allows setting cost on create even without allocations" do
        ce_reg = build(:continuing_education_registration, cost_cents: 10_000)
        expect(ce_reg).to be_valid
      end
    end
  end

  describe ".enroll!" do
    let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 2000) }
    let(:person) { create(:person) }
    let(:registration) { create(:event_registration, event: event, registrant: person) }

    it "enrolls against the person's license for the given number and kind" do
      ce = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW")

      expect(ce.professional_license).to have_attributes(person: person, number: "12345", kind: "LCSW")
      expect(ce.hours).to eq(6)
    end

    it "updates the registration's existing CE record with the license it's given" do
      first = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW", issuing_state: "CA")

      expect(described_class.enroll!(event_registration: registration, number: "99999", kind: "LMFT", issuing_state: "OR")).to eq(first)
      expect(registration.continuing_education_registrations.count).to eq(1)
      expect(first.reload.professional_license).to have_attributes(number: "99999", kind: "LMFT", issuing_state: "OR")
    end

    it "keeps the existing CE record's license details that aren't supplied again" do
      first = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW", expires_on: Date.new(2027, 1, 1))

      described_class.enroll!(event_registration: registration, issuing_state: "OR")

      expect(first.reload.professional_license).to have_attributes(number: "12345", kind: "LCSW", issuing_state: "OR", expires_on: Date.new(2027, 1, 1))
    end

    it "moves the existing CE record onto the registrant's other license when the number matches it" do
      first = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW")
      other = create(:professional_license, person: person, number: "77777", kind: "LMFT")

      described_class.enroll!(event_registration: registration, number: "77777", kind: "LMFT", expires_on: Date.new(2028, 1, 1))

      expect(first.reload.professional_license).to eq(other)
      expect(other.reload.expires_on).to eq(Date.new(2028, 1, 1))
    end

    it "adds a second license when a new event's registration gives a new number" do
      earlier = described_class.enroll!(event_registration: create(:event_registration, registrant: person), number: "12345", kind: "LCSW")

      ce = described_class.enroll!(event_registration: registration, number: "99999", kind: "LCSW")

      expect(person.professional_licenses.pluck(:number)).to contain_exactly("12345", "99999")
      expect(earlier.reload.professional_license.number).to eq("12345")
      expect(ce.professional_license.number).to eq("99999")
    end

    it "gives the existing CE record its own license when a new number would change another event's" do
      earlier = described_class.enroll!(event_registration: create(:event_registration, registrant: person), number: "12345", kind: "LCSW")
      ce = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW")

      described_class.enroll!(event_registration: registration, number: "99999", kind: "LCSW", issuing_state: "OR")

      expect(earlier.reload.professional_license).to have_attributes(number: "12345", issuing_state: nil)
      expect(ce.reload.professional_license).to have_attributes(number: "99999", kind: "LCSW", issuing_state: "OR")
      expect(person.professional_licenses.count).to eq(2)
    end

    it "keeps sharing the license with another event's CE when the number is unchanged" do
      earlier = described_class.enroll!(event_registration: create(:event_registration, registrant: person), number: "12345", kind: "LCSW")
      ce = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW")

      described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW", issuing_state: "OR")

      expect(ce.reload.professional_license).to eq(earlier.reload.professional_license)
      expect(earlier.professional_license.issuing_state).to eq("OR")
    end

    it "leaves an issued certificate's license as issued" do
      first = described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW")
      first.update!(certificate_sent_at: Time.current)

      described_class.enroll!(event_registration: registration, number: "99999", kind: "LCSW")

      expect(first.reload.professional_license.number).to eq("12345")
    end

    it "fills a license's blank state and expiry" do
      described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW",
                              issuing_state: "CA", expires_on: Date.new(2027, 1, 1))

      expect(person.professional_licenses.sole).to have_attributes(issuing_state: "CA", expires_on: Date.new(2027, 1, 1))
    end

    it "leaves what's on file alone when a value isn't supplied" do
      license = create(:professional_license, person: person, number: "12345", kind: "LCSW",
                                              issuing_state: "CA", expires_on: Date.new(2027, 1, 1))

      described_class.enroll!(event_registration: registration, number: "12345", kind: "LCSW", issuing_state: "OR")

      expect(license.reload).to have_attributes(issuing_state: "OR", expires_on: Date.new(2027, 1, 1))
    end

    context "when a double-submit enrolls the same registration twice at once" do
      # Each thread needs its own committed transaction, so this group can't run inside the example's.
      self.use_transactional_tests = false

      around do |example|
        connection = ActiveRecord::Base.connection
        tables = connection.tables.select { |table| connection.column_exists?(table, :id) }
        baseline = tables.index_with { |table| connection.select_value("SELECT MAX(id) FROM #{connection.quote_table_name(table)}").to_i }
        example.run
      ensure
        connection.disable_referential_integrity do
          baseline.each { |table, max_id| connection.execute("DELETE FROM #{connection.quote_table_name(table)} WHERE id > #{max_id}") }
        end
      end

      it "creates one CE registration and one license" do
        arrived = Queue.new
        release = Queue.new
        allow(ProfessionalLicense).to receive(:find_or_create_for).and_wrap_original do |original, **args|
          arrived << true
          release.pop(timeout: 1)
          original.call(**args)
        end

        registration_id = registration.id
        submissions = 2.times.map do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              ActiveRecord::Base.transaction do
                fresh = EventRegistration.find(registration_id)
                fresh.event.title
                described_class.enroll!(event_registration: fresh, number: "12345", kind: "LCSW")
              end
            end
          end
        end
        2.times { arrived.pop(timeout: 1) }
        2.times { release << true }
        submissions.each(&:join)

        expect(registration.continuing_education_registrations.count).to eq(1)
        expect(person.professional_licenses.count).to eq(1)
      end
    end
  end

  describe "hours and cost defaults from the event" do
    it "defaults hours from the event's offered CE hours on create" do
      event = create(:event, ce_hours_offered: 8)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, hours: nil,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.hours).to eq(8)
    end

    it "defaults cost_cents from the event's total CE cost on create" do
      event = create(:event, ce_hours_cost_cents: 12_000)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, cost_cents: nil,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.cost_cents).to eq(12_000)
    end

    it "keeps an explicitly provided cost rather than the event default" do
      event = create(:event, ce_hours_cost_cents: 12_000)
      registration = create(:event_registration, event: event)

      ce_reg = create(:continuing_education_registration,
        event_registration: registration, cost_cents: 5_000,
        professional_license: create(:professional_license, person: registration.registrant))

      expect(ce_reg.cost_cents).to eq(5_000)
    end
  end

  describe "certificate" do
    def ce_reg_for(event:, status:, cost_cents: 0)
      registration = create(:event_registration, event: event, status: status)
      create(:continuing_education_registration,
        event_registration: registration, cost_cents: cost_cents,
        professional_license: create(:professional_license, person: registration.registrant))
    end

    it "is unavailable once an admin denies the CE" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      ce_reg = ce_reg_for(event: event, status: "attended")
      ce_reg.update!(denied_at: Time.current)
      expect(ce_reg.certificate_available?).to be(false)
    end

    it "is available once a CE-eligible training has ended, the registrant attended, and it's paid" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended").certificate_available?).to be(true)
    end

    it "is unavailable when the event does not grant CE" do
      event = create(:event, ce_hours_offered: 0, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended").certificate_available?).to be(false)
    end

    it "is unavailable when the registrant has not attended" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "registered").certificate_available?).to be(false)
    end

    it "is unavailable while there is a CE balance due" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended", cost_cents: 10_000).certificate_available?).to be(false)
    end

    it "requires logged attendance to approximately cover the awarded hours once time is tracked" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      ce_reg = ce_reg_for(event: event, status: "attended") # 6h awarded → needs 324 min (90%)
      reg = ce_reg.event_registration

      # Only 5 hours (300 min) logged — short of the 324-minute threshold.
      create(:event_attendance_time_entry, event_registration: reg,
        signed_in_at: 2.days.ago.change(hour: 9), signed_out_at: 2.days.ago.change(hour: 14))
      expect(ce_reg.certificate_available?).to be(false)

      # Another 30 minutes clears the threshold (330 ≥ 324).
      create(:event_attendance_time_entry, event_registration: reg,
        signed_in_at: 2.days.ago.change(hour: 14), signed_out_at: 2.days.ago.change(hour: 14, min: 30))
      expect(ce_reg.reload.certificate_available?).to be(true)
    end

    it "isn't gated on logged time when no attendance was tracked" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      expect(ce_reg_for(event: event, status: "attended").certificate_available?).to be(true)
    end

    it "requires the CE callout's post-training form to be completed once one is set" do
      event = create(:event, ce_hours_offered: 6, start_date: 3.days.ago, end_date: 1.day.ago)
      form = create(:form, name: "CE Evaluation", anonymous: true)
      required_field = create(:form_field, form:, required: true)
      callout = create(:registration_ticket_callout, event:, builtin_key: "ce_hours", title: "CE hours", form:)

      ce_reg = ce_reg_for(event: event, status: "attended")
      expect(ce_reg.certificate_available?).to be(false)

      EventRegistrationServices::CalloutFormSubmission.call(
        registration: ce_reg.event_registration, callout: callout, form:,
        form_params: { required_field.id.to_s => "Great" }
      )
      expect(ce_reg.reload.certificate_available?).to be(true)
    end

    it "records delivery via certificate_sent_at" do
      ce_reg = create(:continuing_education_registration)
      expect(ce_reg.certificate_sent?).to be(false)
      ce_reg.mark_certificate_sent!
      expect(ce_reg.certificate_sent?).to be(true)
    end

    describe "transfer creates a second record (two-record model, #1944)" do
      let(:origin_event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 10_000, start_date: 3.days.ago, end_date: 1.day.ago) }
      let(:origin_reg) { create(:event_registration, event: origin_event, status: "attended") }
      let(:license) { create(:professional_license, person: origin_reg.registrant) }

      it "carries hours/cost from the source without re-defaulting from the event" do
        # A real transfer leaves a matching stub on the source; that stub is what
        # marks the destination record as transfer-carried.
        origin_reg.continuing_education_registrations.create!(
          professional_license: license, hours: 0, cost_cents: 10_000, skip_event_defaults: true)
        dest_reg = create(:event_registration, event: create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 10_000),
          registrant: origin_reg.registrant, transferred_from_registration: origin_reg)
        ce = dest_reg.continuing_education_registrations.create!(
          professional_license: license, hours: 6, cost_cents: 0, skip_event_defaults: true)

        expect(ce.hours).to eq(6)
        expect(ce.cost_cents).to eq(0)   # the event's $100 default is skipped
        expect(ce).to be_transfer_created
      end

      it "certifies against its own (destination) event, not the source" do
        future = create(:event, ce_hours_offered: 6, start_date: 10.days.from_now, end_date: 12.days.from_now)
        dest_reg = create(:event_registration, event: future, registrant: origin_reg.registrant,
          status: "attended", transferred_from_registration: origin_reg)
        ce = dest_reg.continuing_education_registrations.create!(
          professional_license: license, hours: 6, cost_cents: 0, skip_event_defaults: true)

        # Origin already ended, but the hours are earned at the destination event,
        # which hasn't happened yet → not certifiable until that event ends.
        expect(ce.certificate_available?).to be(false)
        future.update!(start_date: 3.days.ago, end_date: 1.day.ago)
        expect(ce.reload.certificate_available?).to be(true)
      end

      it "links a transfer-created record back to the paid original for the same license" do
        origin_ce = origin_reg.continuing_education_registrations.create!(
          professional_license: license, hours: 0, cost_cents: 10_000, skip_event_defaults: true)
        dest_reg = create(:event_registration, event: create(:event, ce_hours_offered: 6),
          registrant: origin_reg.registrant, transferred_from_registration: origin_reg)
        ce = dest_reg.continuing_education_registrations.create!(
          professional_license: license, hours: 6, cost_cents: 0, skip_event_defaults: true)

        expect(ce.origin_ce_registration).to eq(origin_ce)
      end
    end
  end

  # Payment interface comes from Registerable, driven by the CE record's own
  # cost_cents. Mirrors EventRegistration's payment-method coverage.
  describe "payment interface" do
    let(:ce_reg) { create(:continuing_education_registration, cost_cents: 10_000) }

    def pay(reg, amount)
      payment = create(:payment, amount_cents: amount, amount_cents_remaining: amount)
      create(:allocation, source: payment, allocatable: reg, amount: amount)
    end

    def scholarship_for(reg, amount)
      scholarship = create(:scholarship, recipient: reg.event_registration.registrant, amount_cents: amount)
      create(:allocation, source: scholarship, allocatable: reg, amount: amount)
    end

    describe "#paid_in_full?" do
      it "is paid when the registration is zero-cost" do
        zero = create(:continuing_education_registration, cost_cents: 0)
        expect(zero).to be_paid_in_full
      end

      it "is paid when a scholarship covers the cost" do
        scholarship_for(ce_reg, 10_000)
        expect(ce_reg).to be_paid_in_full
      end

      it "is paid when payments cover the cost" do
        pay(ce_reg, 10_000)
        expect(ce_reg).to be_paid_in_full
      end

      it "is not paid when allocations are insufficient" do
        pay(ce_reg, 5_000)
        expect(ce_reg).not_to be_paid_in_full
      end
    end

    describe "#partially_paid?" do
      it "is false when nothing has been paid" do
        expect(ce_reg).not_to be_partially_paid
      end

      it "is true when a payment covers some but not all of the cost" do
        pay(ce_reg, 5_000)
        expect(ce_reg).to be_partially_paid
      end

      it "is false when only a scholarship covers part of the cost" do
        scholarship_for(ce_reg, 5_000)
        expect(ce_reg).not_to be_partially_paid
      end

      it "is false when paid in full" do
        pay(ce_reg, 10_000)
        expect(ce_reg).not_to be_partially_paid
      end
    end

    # The Allocation model blocks allocating past the cost, so an over-allocation
    # only arises when the cost is later lowered under existing payments — which is
    # exactly what a merge does when it combines two paid records onto one.
    describe "#over_allocated?" do
      it "is false when allocations are within the cost" do
        pay(ce_reg, 5_000)
        expect(ce_reg).not_to be_over_allocated
      end

      it "is true when a $0-cost registration still carries a payment" do
        pay(ce_reg, 5_000)
        ce_reg.update_columns(cost_cents: 0)
        expect(ce_reg).to be_over_allocated
      end

      it "is true when allocations exceed the cost" do
        pay(ce_reg, 10_000)
        ce_reg.update_columns(cost_cents: 4_000)
        expect(ce_reg).to be_over_allocated
      end
    end

    describe "#discounted? / #discount_sum" do
      it "are set by a discount allocation" do
        create(:allocation, source: create(:discount, amount_cents: 4_000), allocatable: ce_reg, amount: 4_000)
        expect(ce_reg).to be_discounted
        expect(ce_reg.discount_sum).to eq(4_000)
      end

      it "ignore a payment-only allocation" do
        pay(ce_reg, 4_000)
        expect(ce_reg).not_to be_discounted
        expect(ce_reg.discount_sum).to eq(0)
      end
    end

    describe "#payments_sum vs #allocations_sum" do
      it "counts cash for payments_sum and every source for allocations_sum" do
        pay(ce_reg, 4_000)
        scholarship_for(ce_reg, 3_000)
        ce_reg.reload

        expect(ce_reg.payments_sum).to eq(4_000)
        expect(ce_reg.allocations_sum).to eq(7_000)
        expect(ce_reg.remaining_cost).to eq(3_000)
      end
    end

    it "issues no per-row queries when allocations are preloaded" do
      pay(ce_reg, 10_000)
      preloaded = ContinuingEducationRegistration.includes(:allocations).find(ce_reg.id)

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

    it "reports discounted? and discount_sum like an event registration" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
      expect(ce_reg.discounted?).to be(false)
      expect(ce_reg.discount_sum).to eq(0)

      create(:allocation, source: create(:discount, amount_cents: 4_000), allocatable: ce_reg, amount: 4_000)

      expect(ce_reg.discounted?).to be(true)
      expect(ce_reg.discount_sum).to eq(4_000)
    end

    it "labels payment status Due → Partial → Paid" do
      ce_reg = create(:continuing_education_registration, cost_cents: 10_000)
      expect(ce_reg.payment_status_label).to eq("Due")

      payment = create(:payment, amount_cents: 10_000, amount_cents_remaining: 10_000)
      create(:allocation, source: payment, allocatable: ce_reg, amount: 4_000)
      expect(ce_reg.payment_status_label).to eq("Partial")

      create(:allocation, source: payment, allocatable: ce_reg, amount: 6_000)
      expect(ce_reg.payment_status_label).to eq("Paid")
    end
  end

  describe ".search_by_params" do
    let(:person) { create(:person) }
    let(:license) { create(:professional_license, person: person) }

    def ce_reg(license:, certificate_sent_at: nil)
      registration = create(:event_registration, registrant: license.person)
      create(:continuing_education_registration,
        event_registration: registration,
        professional_license: license,
        certificate_sent_at: certificate_sent_at)
    end

    it "filters to a single license" do
      mine = ce_reg(license: license)
      other = ce_reg(license: create(:professional_license))

      results = ContinuingEducationRegistration.search_by_params(professional_license_id: license.id)

      expect(results).to include(mine)
      expect(results).not_to include(other)
    end

    it "filters by issued-on date range" do
      in_range = ce_reg(license: license, certificate_sent_at: Date.new(2026, 6, 15).noon)
      before_range = ce_reg(license: license, certificate_sent_at: Date.new(2025, 12, 31).noon)

      results = ContinuingEducationRegistration.search_by_params(issued_from: "2026-01-01", issued_to: "2026-12-31")

      expect(results).to include(in_range)
      expect(results).not_to include(before_range)
    end

    it "ignores an unparseable date" do
      reg = ce_reg(license: license, certificate_sent_at: Time.current)

      results = ContinuingEducationRegistration.search_by_params(issued_from: "not-a-date")

      expect(results).to include(reg)
    end
  end
end
