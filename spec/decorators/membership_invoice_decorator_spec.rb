require "rails_helper"

RSpec.describe MembershipInvoiceDecorator, type: :decorator do
  def invoice(cost_cents: 2_500, start_date: Date.current, paid: 0)
    record = create(:membership_invoice,
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
    create(:allocation, source: create(:payment, amount_cents: paid), allocatable: record, amount: paid) if paid.positive?
    record.reload.decorate
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
      decorated = invoice
      decorated.object.update_column(:payment_in_progress_at, Time.current)

      badge = decorated.status_badge

      expect(badge.label).to eq("Payment in progress")
      expect(badge.classes).to eq(described_class::BADGE_CLASSES[:blue])
    end
  end

  describe "#autopay_action" do
    it "is nil when autopay is not ready" do
      expect(invoice.autopay_action(autopay_ready: false)).to be_nil
    end

    it "is pending inside the renewal window" do
      expect(invoice(start_date: Date.current + 1.day).autopay_action(autopay_ready: true)).to eq(:pending)
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
      decorated = invoice
      decorated.object.charge_attempts.create!(
        attempt_number: 1, status: "failed", amount_cents: 2_500, attempted_at: Time.current
      )

      expect(decorated.autopay_action(autopay_ready: true)).to eq(:pay_now)
    end

    it "is pay now when a checkout session is stored" do
      decorated = invoice
      decorated.object.update_column(:checkout_session_id, "cs_test_123")

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
