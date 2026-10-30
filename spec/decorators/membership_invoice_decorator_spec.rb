require "rails_helper"

RSpec.describe MembershipInvoiceDecorator, type: :decorator do
  def invoice(cost_cents: 2_500, start_date: Date.current, paid: 0, payment_in_progress: false,
    latest_attempt: nil, checkout_session_id: nil)
    record = build_stubbed(:membership_invoice,
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day,
      checkout_session_id: checkout_session_id)
    allow(record).to receive(:payment_in_progress?).and_return(payment_in_progress)
    allow(record).to receive(:allocations_sum).and_return(paid)
    allow(record).to receive(:remaining_cost).and_return([ cost_cents - paid, 0 ].max)
    allow(record).to receive(:paid_in_full?).and_return(paid >= cost_cents)
    allow(record).to receive(:partially_paid?).and_return(paid.positive? && paid < cost_cents)
    allow(record).to receive(:latest_attempt).and_return(latest_attempt)
    record.decorate
  end

  describe "#status_badge" do
    it "reads Upcoming · Paid for a paid future invoice" do
      badge = invoice(start_date: Date.current + 1.day, paid: 2_500).status_badge
      expect(badge.label).to eq("Upcoming · Paid")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:green])
    end

    it "reads Upcoming with amount before the year starts" do
      expect(invoice(start_date: Date.current + 1.day).status_badge.label).to eq("Upcoming · $25")
    end

    it "reads Paid for a settled year" do
      expect(invoice(paid: 2_500).status_badge.label).to eq("Paid")
    end

    it "reads Paid for a comped year" do
      expect(invoice(cost_cents: 0).status_badge.label).to eq("Paid")
    end

    it "reads Overdue with amount for an unpaid invoice whose term has started" do
      badge = invoice(start_date: Date.current - 1).status_badge

      expect(badge.label).to eq("Overdue · $25")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:red])
    end

    it "reads Partially paid with amount for an invoice after a part payment" do
      expect(invoice(paid: 1_000, start_date: Date.current).status_badge.label).to eq("Partially paid · $15")
    end

    it "reads Payment in progress while a checkout is active" do
      badge = invoice(payment_in_progress: true).status_badge

      expect(badge.label).to eq("Payment in progress")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:blue])
    end
  end

  describe "#autopay_action" do
    it "offers Pay now when autopay is not ready" do
      expect(invoice.autopay_action(autopay_ready: false)).to eq(:pay_now)
    end

    it "offers no action inside the renewal window when autopay is ready" do
      expect(invoice(start_date: Date.current + 1.day).autopay_action(autopay_ready: true)).to eq(:none)
    end

    it "is scheduled outside the renewal window" do
      future = invoice(start_date: Date.current + Membership.renewal_window_days + 1.day)
      expect(future.autopay_action(autopay_ready: true)).to eq(:scheduled)
    end

    it "is pay now for an invoice older than the retry window" do
      past = invoice(start_date: Date.current - MembershipChargeAttempt::RETRY_WINDOW_DAYS - 1.day)
      expect(past.autopay_action(autopay_ready: true)).to eq(:pay_now)
    end

    it "is pay now after a failed attempt" do
      decorated = invoice(latest_attempt: double(failed?: true))

      expect(decorated.autopay_action(autopay_ready: true)).to eq(:pay_now)
    end

    it "is pay now when a checkout session is stored" do
      decorated = invoice(checkout_session_id: "cs_test_123")

      expect(decorated.autopay_action(autopay_ready: true)).to eq(:pay_now)
    end
  end

  describe "formatting" do
    it "renders the invoice as a date range" do
      expect(invoice(start_date: Date.new(2026, 10, 14)).period_range).to eq("Oct 14, 2026 – Oct 13, 2027")
    end

    it "renders money without trailing cents" do
      decorated = invoice(cost_cents: 2_500, paid: 1_000)

      expect(decorated.cost).to eq("$25")
      expect(decorated.paid).to eq("$10")
      expect(decorated.remaining).to eq("$15")
    end

    it "knows a comped year" do
      expect(invoice(cost_cents: 0)).to be_comped
      expect(invoice).not_to be_comped
    end
  end
end
