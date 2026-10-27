require "rails_helper"

RSpec.describe MembershipDecorator, type: :decorator do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents) }

  def create_stripe_subscription(membership, status: "active", ends_at: nil)
    customer = Pay::Customer.create!(owner: membership.person, processor: "stripe",
      processor_id: "cus_#{membership.id}", default: true)
    Pay::Stripe::Subscription.create!(customer: customer, name: "default",
      processor_id: "sub_#{membership.id}", processor_plan: "membership",
      status: status, quantity: 1, ends_at: ends_at,
      metadata: { "membership_id" => membership.id })
  end

  describe "#cost_label" do
    it "names the standard cost when there is no override" do
      expect(create(:membership, cost_cents: nil).decorate.cost_label)
        .to eq("Standard (#{standard_cost})")
    end

    it "names the locked cost when there is one" do
      expect(create(:membership, cost_cents: 1_500).decorate.cost_label).to eq("Locked at $15")
    end

    it "treats a zero cost as locked, not standard" do
      expect(create(:membership, cost_cents: 0).decorate.cost_label).to eq("Locked at $0")
    end
  end

  describe "#auto_renewal_label" do
    it "reads enabled when not autorenewal_cancelled" do
      expect(create(:membership).decorate.auto_renewal_label).to eq("enabled")
    end

    it "reads the cancelled date once autorenewal_cancelled" do
      subscription = create(:membership, autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(subscription.decorate.auto_renewal_label).to eq("cancelled on Aug 3, 2026")
    end

    it "leaves the label alone when the Stripe subscription is ending" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.from_now)

      expect(membership.decorate.auto_renewal_label).to eq("enabled")
    end
  end

  describe "#stripe_badge" do
    it "is green while the membership's subscription is active" do
      membership = create(:membership)
      create_stripe_subscription(membership)

      badge = membership.decorate.stripe_badge

      expect(badge[:label]).to eq("Stripe active")
      expect(badge[:classes]).to include("green")
    end

    it "is nil for a subscription set to cancel at the period's end" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.from_now)

      expect(membership.decorate.stripe_badge).to be_nil
    end

    it "is amber while a payment is past due" do
      membership = create(:membership)
      create_stripe_subscription(membership, status: "past_due")

      badge = membership.decorate.stripe_badge

      expect(badge[:label]).to eq("Stripe past due")
      expect(badge[:classes]).to include("amber")
    end

    it "is nil without a subscription, so the directory shows nothing to collect from" do
      expect(create(:membership).decorate.stripe_badge).to be_nil
    end

    it "is nil once the subscription has ended" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.ago)

      expect(membership.decorate.stripe_badge).to be_nil
    end

    it "reads this membership's own subscription, not another membership's" do
      membership = create(:membership)
      other = create(:membership, person: membership.person, autorenewal_cancelled_at: Time.current,
        start_date: Date.current - 3.years, end_date: Date.current - 2.years)
      create_stripe_subscription(other)

      expect(membership.decorate.stripe_badge).to be_nil
    end
  end

  describe "#status_label" do
    it "reads Upcoming for a membership billed for a future period but not dated yet" do
      membership = create(:membership).tap { |m| m.update!(start_date: nil, end_date: nil) }
      create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.month, end_date: Date.current + 1.year - 1.day)

      expect(membership.reload.decorate.status_label).to eq("Upcoming")
      expect(membership.decorate.status_classes).to include("blue")
    end
  end

  describe "#coverage_label and #coverage_date" do
    it "points at the end date while the membership is active" do
      membership = create(:membership, start_date: Date.current - 1.month, end_date: Date.current + 11.months).decorate

      expect(membership.coverage_label).to eq("Membership good through:")
      expect(membership.coverage_date).to eq(Date.current + 11.months)
    end

    it "points at the start date when the membership has not begun" do
      membership = create(:membership, start_date: Date.current + 1.month, end_date: Date.current + 13.months).decorate

      expect(membership.coverage_label).to eq("Membership starts:")
      expect(membership.coverage_date).to eq(Date.current + 1.month)
    end

    it "falls back to the first upcoming invoice when there is no start date" do
      membership = create(:membership).tap { |m| m.update!(start_date: nil, end_date: nil) }
      invoice = create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.month, end_date: Date.current + 1.year)

      expect(membership.reload.decorate.coverage_label).to eq("Membership starts:")
      expect(membership.decorate.coverage_date).to eq(invoice.start_date)
    end

    it "points at the end date once the membership has ended" do
      membership = create(:membership, start_date: Date.current - 2.years, end_date: Date.current - 1.year).decorate

      expect(membership.coverage_label).to eq("Membership ended:")
      expect(membership.coverage_date).to eq(Date.current - 1.year)
    end
  end
end
