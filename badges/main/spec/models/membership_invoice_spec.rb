require "rails_helper"

RSpec.describe MembershipInvoice, type: :model do
  describe "validations" do
    it "requires both dates" do
      invoice = build(:membership_invoice, start_date: nil, end_date: nil)
      expect(invoice).not_to be_valid
      expect(invoice.errors[:start_date]).to be_present
      expect(invoice.errors[:end_date]).to be_present
    end

    it "rejects an end date before the start date" do
      invoice = build(:membership_invoice, start_date: Date.current, end_date: Date.current - 1)
      expect(invoice).not_to be_valid
      expect(invoice.errors[:end_date]).to be_present
    end

    it "allows a single-day invoice" do
      expect(build(:membership_invoice, start_date: Date.current, end_date: Date.current)).to be_valid
    end

    it "rejects a negative cost" do
      invoice = build(:membership_invoice, cost_cents: -1)
      expect(invoice).not_to be_valid
      expect(invoice.errors[:cost_cents]).to be_present
    end

    it "allows a zero cost, meaning a comped year" do
      expect(build(:membership_invoice, :comped)).to be_valid
    end
  end

  describe "#cost_dollars=" do
    it "parses a valid dollar amount" do
      invoice = build(:membership_invoice, cost_cents: 2_500)

      invoice.cost_dollars = "99.50"

      expect(invoice.cost_cents).to eq(9_950)
      expect(invoice).to be_valid
    end

    it "rejects a malformed amount without changing the stored amount" do
      invoice = build(:membership_invoice, cost_cents: 2_500)

      invoice.cost_dollars = "abc"

      expect(invoice).not_to be_valid
      expect(invoice.errors[:cost_dollars]).to be_present
      expect(invoice.cost_cents).to eq(2_500)
    end

    it "leaves the amount unchanged when blank" do
      invoice = build(:membership_invoice, cost_cents: 2_500)

      invoice.cost_dollars = ""

      expect(invoice.cost_cents).to eq(2_500)
    end
  end

  describe "#payment_in_progress?" do
    it "is true while a checkout is inside the payment window" do
      invoice = create(:membership_invoice)
      invoice.update_column(:payment_in_progress_at, 30.minutes.ago)

      expect(invoice).to be_payment_in_progress
    end

    it "is false once the checkout window has passed" do
      invoice = create(:membership_invoice)
      invoice.update_column(:payment_in_progress_at, 32.minutes.ago)

      expect(invoice).not_to be_payment_in_progress
    end

    it "is true while a recent autopay attempt is pending" do
      invoice = create(:membership_invoice)
      invoice.charge_attempts.create!(
        attempt_number: 1,
        status: "pending",
        amount_cents: 100,
        attempted_at: 5.minutes.ago
      )

      expect(invoice).to be_payment_in_progress
    end

    it "is false when the only pending attempt is stale" do
      invoice = create(:membership_invoice)
      invoice.charge_attempts.create!(
        attempt_number: 1,
        status: "pending",
        amount_cents: 100,
        attempted_at: 61.minutes.ago
      )

      expect(invoice).not_to be_payment_in_progress
    end

    it "is false when no checkout or pending attempt exists" do
      expect(create(:membership_invoice)).not_to be_payment_in_progress
    end
  end

  describe "#mark_payment_in_progress!" do
    it "clears any previous checkout session id" do
      invoice = create(:membership_invoice, checkout_session_id: "cs_old")

      invoice.mark_payment_in_progress!

      expect(invoice.payment_in_progress_at).to be_present
      expect(invoice.checkout_session_id).to be_nil
    end
  end

  describe "#clear_payment_in_progress!" do
    it "clears the lease and checkout session id together" do
      invoice = create(:membership_invoice,
        payment_in_progress_at: Time.current,
        checkout_session_id: "cs_test_123")

      invoice.clear_payment_in_progress!

      expect(invoice.payment_in_progress_at).to be_nil
      expect(invoice.checkout_session_id).to be_nil
    end
  end

  describe "overlap" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }
    # Anchor the fixture in the past so cancelling its membership never trips
    # Membership#expire_unbilled_future_invoices (which drops unbilled future years).
    let(:existing_start) { Date.current - 1.month }
    let(:existing_end) { Date.current + 1.year }
    let!(:existing) do
      create(:membership_invoice,
        membership: subscription,
        start_date: existing_start,
        end_date: existing_end)
    end

    it "rejects a invoice overlapping an existing one" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: existing_start + 1.week,
        end_date: existing_end + 1.week)

      expect(invoice).not_to be_valid
      expect(invoice.errors[:base].join).to match(/overlapping/)
    end

    it "rejects a invoice that merely shares the last day" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: existing_end,
        end_date: existing_end + 1.year)

      expect(invoice).not_to be_valid
    end

    it "accepts a invoice starting the day after the previous one ends" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: existing_end + 1.day,
        end_date: existing_end + 1.year)

      expect(invoice).to be_valid
    end

    it "allows an overlap under a different membership for the same person" do
      existing.membership.update!(renewal_off_at: Time.current)
      rejoined = create(:membership, person: person,
        start_date: subscription.end_date + 1.day, end_date: subscription.end_date + 1.year)

      invoice = build(:membership_invoice,
        membership: rejoined,
        start_date: existing_start + 1.week,
        end_date: existing_end + 1.week)

      expect(invoice).to be_valid
    end

    it "rejects a gap between invoices on the same membership" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: existing_end + 2.days,
        end_date: existing_end + 1.year)

      expect(invoice).not_to be_valid
      expect(invoice.errors[:base].join).to match(/contiguous/)
    end

    it "allows another person to hold the same dates" do
      invoice = build(:membership_invoice,
        membership: create(:membership),
        start_date: existing.start_date,
        end_date: existing.end_date)

      expect(invoice).to be_valid
    end

    it "does not treat a persisted invoice as overlapping itself" do
      expect(existing.reload).to be_valid
    end
  end

  describe "the payment interface from Registerable" do
    let(:invoice) { create(:membership_invoice, cost_cents: 2_500) }

    it "treats a comped year as paid with nothing allocated" do
      expect(create(:membership_invoice, :comped)).to be_paid_in_full
    end

    it "is unpaid until allocations cover the cost" do
      expect(invoice).not_to be_paid_in_full
      expect(invoice.remaining_cost).to eq(2_500)
    end

    it "is paid once a payment covers the cost" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      expect(invoice.reload).to be_paid_in_full
      expect(invoice.remaining_cost).to eq(0)
      expect(invoice.payments_sum).to eq(2_500)
    end

    it "is partially paid when a payment covers only part of the cost" do
      create(:allocation, source: create(:payment, amount_cents: 1_000), allocatable: invoice, amount: 1_000)

      expect(invoice.reload).to be_partially_paid
      expect(invoice.remaining_cost).to eq(1_500)
    end

    it "counts a discount towards the cost but not towards payments" do
      create(:allocation, source: create(:discount, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      expect(invoice.reload).to be_paid_in_full
      expect(invoice).to be_discounted
      expect(invoice.discount_sum).to eq(2_500)
      expect(invoice.payments_sum).to eq(0)
      expect(invoice).not_to be_payment_received
    end
  end

  describe "#receipt_available?" do
    let(:invoice) { create(:membership_invoice, cost_cents: 2_500) }

    it "needs a payment that settles the year" do
      expect(invoice).not_to be_receipt_available

      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      expect(invoice.reload).to be_receipt_available
    end

    it "is unavailable when only a credit or a comp settles the year" do
      create(:allocation, source: create(:discount, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      expect(invoice.reload).to be_paid_in_full
      expect(invoice).not_to be_receipt_available
      expect(create(:membership_invoice, :comped)).not_to be_receipt_available
    end
  end

  describe "coverage scopes" do
    let!(:past) do
      create(:membership_invoice, :comped,
        start_date: Date.current - 2.years, end_date: Date.current - 1.year - 1.day)
    end
    let!(:present) do
      create(:membership_invoice, :comped,
        membership: past.membership,
        start_date: Date.current - 1.year, end_date: Date.current - 1.day + 1.year)
    end
    let!(:future) do
      create(:membership_invoice, :comped,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)
    end

    it ".active_on finds only the invoice containing the date" do
      expect(described_class.active_on(Date.current)).to contain_exactly(present)
      expect(described_class.active_on(Date.current - 18.months)).to contain_exactly(past)
    end

    it ".active_on includes both boundary days" do
      expect(described_class.active_on(present.start_date)).to include(present)
      expect(described_class.active_on(present.end_date)).to include(present)
    end

    it ".active_on defaults to today" do
      expect(described_class.active_on).to contain_exactly(present)
    end

    it ".expiring_between finds invoices ending in the window" do
      expect(described_class.expiring_between(Date.current, Date.current + 30.days))
        .to be_empty
      expect(described_class.expiring_between(present.end_date - 1.day, present.end_date + 1.day))
        .to contain_exactly(present)
    end

    it "agrees with #active_on?" do
      expect(present.active_on?(Date.current)).to be(true)
      expect(future.active_on?(Date.current)).to be(false)
      expect(present.active_on?(present.end_date)).to be(true)
      expect(present.active_on?(present.end_date + 1.day)).to be(false)
    end
  end

  describe "payment scopes" do
    let!(:comped) { create(:membership_invoice, :comped) }
    let!(:unpaid) { create(:membership_invoice, cost_cents: 2_500) }
    let!(:part_paid) { create(:membership_invoice, cost_cents: 2_500) }
    let!(:settled) { create(:membership_invoice, cost_cents: 2_500) }

    before do
      create(:allocation, source: create(:payment, amount_cents: 1_000), allocatable: part_paid, amount: 1_000)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: settled, amount: 2_500)
    end

    it ".paid_in_full counts a comped invoice and a settled one" do
      expect(described_class.paid_in_full).to contain_exactly(comped, settled)
    end

    it ".not_paid_in_full counts unpaid and part-paid, never a comped invoice" do
      expect(described_class.not_paid_in_full).to contain_exactly(unpaid, part_paid)
    end

    it "agrees with #paid_in_full?" do
      expect(described_class.paid_in_full.map(&:paid_in_full?)).to all(be(true))
      expect(described_class.not_paid_in_full.map(&:paid_in_full?)).to all(be(false))
    end
  end

  describe "overdue semantics" do
    it "treats an unpaid invoice whose term has started as overdue" do
      invoice = create(:membership_invoice, cost_cents: 2_500, start_date: Date.current - 1)
      expect(invoice).to be_overdue
      expect(described_class.overdue).to include(invoice)
    end

    it "treats an unpaid invoice whose term starts today as overdue" do
      invoice = create(:membership_invoice, cost_cents: 2_500, start_date: Date.current)
      expect(invoice).to be_overdue
      expect(described_class.overdue).to include(invoice)
    end

    it "does not treat an unpaid invoice whose term hasn't started as overdue" do
      invoice = create(:membership_invoice, cost_cents: 2_500, start_date: Date.current + 1)
      expect(invoice).not_to be_overdue
      expect(described_class.overdue).not_to include(invoice)
    end

    it "never treats a paid or comped invoice as overdue" do
      create(:membership_invoice, cost_cents: 0, start_date: Date.current - 1)
      paid = create(:membership_invoice, cost_cents: 2_500, start_date: Date.current - 1)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: paid, amount: 2_500)

      expect(paid.reload).not_to be_overdue
      expect(described_class.overdue).not_to include(paid)
    end
  end

  describe "#upcoming?" do
    it "is true for an invoice whose term hasn't started" do
      expect(create(:membership_invoice, start_date: Date.current + 1)).to be_upcoming
    end

    it "is false once the term has started" do
      expect(create(:membership_invoice, start_date: Date.current)).not_to be_upcoming
      expect(create(:membership_invoice, start_date: Date.current - 1)).not_to be_upcoming
    end
  end

  describe "autopay windows" do
    it "is issued through the renewal window" do
      inside = create(:membership_invoice,
        start_date: Date.current + Membership.renewal_window_days)
      outside = create(:membership_invoice,
        start_date: Date.current + Membership.renewal_window_days + 1.day)

      expect(inside).to be_autopay_issued
      expect(outside).not_to be_autopay_issued
      expect(described_class.autopay_issued).to include(inside)
      expect(described_class.autopay_issued).not_to include(outside)
    end

    it "is chargeable through the retry window" do
      inside = create(:membership_invoice,
        start_date: Date.current - MembershipChargeAttempt::RETRY_WINDOW_DAYS)
      outside = create(:membership_invoice,
        start_date: Date.current - MembershipChargeAttempt::RETRY_WINDOW_DAYS - 1.day)

      expect(inside).to be_autopay_chargeable
      expect(outside).not_to be_autopay_chargeable
      expect(described_class.autopay_chargeable).to include(inside)
      expect(described_class.autopay_chargeable).not_to include(outside)
    end

    it "does not charge an invoice beyond the renewal window" do
      future = create(:membership_invoice,
        start_date: Date.current + Membership.renewal_window_days + 1.day)

      expect(future).not_to be_autopay_chargeable
    end
  end

  describe "#registrant" do
    it "is the subscription's person, so payment code can stay type-agnostic" do
      invoice = create(:membership_invoice)

      expect(invoice.registrant).to eq(invoice.membership.person)
    end
  end

  describe "#person" do
    it "comes through the subscription" do
      subscription = create(:membership)
      expect(create(:membership_invoice, membership: subscription).person).to eq(subscription.person)
    end
  end

  describe "#deletable?" do
    let(:person) { create(:person) }
    let(:subscription) do
      create(:membership, person: person,
        start_date: Date.current - 1.year,
        end_date: Date.current + 2.years - 1.day)
    end

    def term_invoice(start_date, cost_cents: Membership.annual_cost_cents)
      create(:membership_invoice, membership: subscription, cost_cents: cost_cents,
        start_date: start_date, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
    end

    let!(:past) { term_invoice(Date.current - 1.year) }
    let!(:current) { term_invoice(Date.current) }
    let!(:future) { term_invoice(Date.current + 1.year) }

    it "blocks deleting a middle invoice because it would leave a gap" do
      expect(current).not_to be_deletable
      expect(current.deletion_blocked_reason).to match(/gap/)
    end

    it "is true for an invoice beyond the term when another invoice remains" do
      subscription.update_columns(end_date: current.end_date)

      expect(future).to be_deletable
      expect(future.deletion_blocked_reason).to be_nil
    end

    it "is false once anything is allocated to it" do
      create(:allocation, source: create(:payment, amount_cents: 100), allocatable: future, amount: 100)

      expect(future.reload).not_to be_deletable
      expect(future.deletion_blocked_reason).to match(/payments or credits/)
    end

    it "blocks deleting the only invoice covering the term" do
      subscription.update_columns(start_date: past.start_date, end_date: past.end_date)

      expect(past).not_to be_deletable
      expect(past.deletion_blocked_reason).to eq("it is the only invoice covering the membership term")
    end

    it "is false when it is the membership's only invoice" do
      only = create(:membership_invoice, membership: create(:membership))

      expect(only).not_to be_deletable
      expect(only.deletion_blocked_reason).to eq("it is the membership's only invoice")
    end

    it "blocks destroy at the model level" do
      subscription.update_columns(start_date: past.start_date, end_date: past.end_date)

      expect { past.destroy }.not_to change(MembershipInvoice, :count)
      expect(past.errors[:base].join).to match(/Cannot delete/)
    end

    context "with a comped invoice beyond the term" do
      let!(:future) { term_invoice(Date.current + 1.year, cost_cents: 0) }

      it "is deletable" do
        subscription.update_columns(end_date: current.end_date)

        expect(future).to be_deletable
      end
    end
  end

  describe ".by_person_name" do
    it "filters to invoices whose person's name matches" do
      named = create(:person, first_name: "Bartholomew", last_name: "Snazzlepants")
      matching = create(:membership_invoice, membership: create(:membership, person: named))
      other = create(:membership_invoice)

      expect(described_class.by_person_name("Bartholomew")).to include(matching)
      expect(described_class.by_person_name("Bartholomew")).not_to include(other)
    end

    it "is a no-op when the query is blank" do
      invoice = create(:membership_invoice)
      expect(described_class.by_person_name("")).to include(invoice)
      expect(described_class.by_person_name(nil)).to include(invoice)
    end
  end
end
