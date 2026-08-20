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

  describe "overlap" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }
    let!(:existing) do
      create(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "rejects a invoice overlapping an existing one" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2027, 1, 1),
        end_date: Date.new(2027, 12, 31))

      expect(invoice).not_to be_valid
      expect(invoice.errors[:base].join).to match(/overlapping/)
    end

    it "rejects a invoice that merely shares the last day" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2027, 10, 13),
        end_date: Date.new(2028, 10, 12))

      expect(invoice).not_to be_valid
    end

    it "accepts a invoice starting the day after the previous one ends" do
      invoice = build(:membership_invoice,
        membership: subscription,
        start_date: Date.new(2027, 10, 14),
        end_date: Date.new(2028, 10, 13))

      expect(invoice).to be_valid
    end

    it "rejects an overlap that sits under a different subscription for the same person" do
      existing.membership.update!(cancelled_at: Time.current)
      rejoined = create(:membership, person: person)

      invoice = build(:membership_invoice,
        membership: rejoined,
        start_date: Date.new(2027, 1, 1),
        end_date: Date.new(2027, 12, 31))

      expect(invoice).not_to be_valid
      expect(invoice.errors[:base].join).to match(/overlapping/)
    end

    it "allows another person to hold the same dates" do
      invoice = build(:membership_invoice,
        membership: create(:membership),
        start_date: existing.start_date,
        end_date: existing.end_date)

      expect(invoice).to be_valid
    end

    it "does not treat a persisted invoice as overlapping itself" do
      existing.cost_cents = 3_000
      expect(existing).to be_valid
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

    it "does not respond to the certificate interface" do
      expect(invoice).not_to respond_to(:certificate_available?)
    end
  end

  describe "#cost_cents" do
    it "cannot be lowered below what has already been allocated" do
      invoice = create(:membership_invoice, cost_cents: 2_500)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: invoice, amount: 2_500)

      invoice.reload.cost_cents = 1_000
      expect(invoice).not_to be_valid
      expect(invoice.errors[:cost_cents].join).to match(/already allocated/)
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

  describe "the grace window" do
    let(:grace) { Membership::GRACE_PERIOD_DAYS }

    def term_starting(days_ago, cost_cents: 2_500)
      create(:membership_invoice,
        cost_cents: cost_cents,
        start_date: Date.current - days_ago,
        end_date: Date.current - days_ago + 1.year - 1.day)
    end

    it "treats an unpaid invoice inside the window as not overdue" do
      invoice = term_starting(grace - 1)
      expect(described_class.overdue).to be_empty
      expect(invoice).not_to be_overdue
      expect(invoice).to be_within_grace
    end

    it "treats an unpaid invoice past the window as overdue" do
      invoice = term_starting(grace + 1)
      expect(described_class.overdue).to contain_exactly(invoice)
      expect(invoice).to be_overdue
      expect(invoice).not_to be_within_grace
    end

    it "counts the window's final day as still in grace" do
      invoice = term_starting(grace)
      expect(invoice).to be_within_grace
      expect(described_class.overdue).to be_empty
    end

    it "never treats a paid or comped invoice as overdue" do
      term_starting(grace + 1, cost_cents: 0)
      paid = term_starting(grace + 1)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: paid, amount: 2_500)

      expect(described_class.overdue).to be_empty
      expect(paid.reload).not_to be_overdue
      expect(paid).not_to be_within_grace
    end

    it ".paid_or_within_grace is the exact complement of .overdue" do
      term_starting(grace + 1)
      term_starting(grace - 1)
      term_starting(grace + 1, cost_cents: 0)

      overdue_ids = described_class.overdue.ids
      honored_ids = described_class.paid_or_within_grace.ids

      expect(overdue_ids & honored_ids).to be_empty
      expect((overdue_ids + honored_ids).sort).to eq(described_class.ids.sort)
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
end
