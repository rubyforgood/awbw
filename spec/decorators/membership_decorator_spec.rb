require "rails_helper"

RSpec.describe MembershipDecorator, type: :decorator do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents) }

  def create_stripe_subscription(membership, ends_at: nil)
    customer = Pay::Customer.create!(owner: membership.person, processor: "stripe",
      processor_id: "cus_#{membership.id}", default: true)
    Pay::Subscription.create!(customer: customer, name: "default",
      processor_id: "sub_#{membership.id}", processor_plan: "membership",
      status: "active", quantity: 1, ends_at: ends_at,
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

    it "reads the date automatic renewal stops when the Stripe subscription is ending" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: Time.utc(2027, 1, 1, 8))

      expect(membership.decorate.auto_renewal_label).to eq("stops Jan 1, 2027")
    end
  end

  describe "#subscription_stopping?" do
    it "is true while a billing-portal cancellation waits for the period to end" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.from_now)

      expect(membership.decorate).to be_subscription_stopping
    end

    it "is false once the subscription has ended" do
      membership = create(:membership)
      create_stripe_subscription(membership, ends_at: 1.month.ago)

      expect(membership.decorate).not_to be_subscription_stopping
    end

    it "is false when the membership's own renewals are already off" do
      membership = create(:membership, autorenewal_cancelled_at: Time.current)
      create_stripe_subscription(membership, ends_at: 1.month.from_now)

      expect(membership.decorate).not_to be_subscription_stopping
    end

    it "is false without a subscription" do
      expect(create(:membership).decorate).not_to be_subscription_stopping
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
