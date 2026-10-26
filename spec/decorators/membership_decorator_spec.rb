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

    it "is green for a subscription set to cancel at the period's end" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.from_now)

      expect(membership.decorate.stripe_badge[:label]).to eq("Stripe active")
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

  describe "#period_label" do
    # period_label reads "present" whenever end_date is still ahead of Date.current,
    # so pin "now" to keep the fixed 2027 end dates on the present side of the fence.
    around { |example| travel_to(Time.zone.local(2026, 9, 1, 12)) { example.run } }

    it "shows the date range when current and not autorenewal_cancelled" do
      membership = create(:membership, start_date: Date.new(2025, 1, 15), end_date: Date.new(2027, 1, 15))

      expect(membership.reload.decorate.period_label).to eq("Jan 15, 2025 – present")
    end

    it "is nil when there are no dates" do
      membership = build(:membership, start_date: nil, end_date: nil)

      expect(membership.decorate.period_label).to be_nil
    end

    it "shows the fixed end date when cancelled and expired" do
      membership = create(:membership, start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 12, 31), autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(membership.reload.decorate.period_label).to eq("Jan 1, 2025 – Dec 31, 2025")
    end

    it "shows present when cancelled but still current" do
      membership = create(:membership, start_date: Date.new(2025, 1, 1), end_date: Date.new(2027, 1, 1), autorenewal_cancelled_at: Time.zone.parse("2026-08-03 12:00"))

      expect(membership.reload.decorate.period_label).to eq("Jan 1, 2025 – present")
    end
  end
end
