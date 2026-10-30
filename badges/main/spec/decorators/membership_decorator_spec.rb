require "rails_helper"

RSpec.describe MembershipDecorator, type: :decorator do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents) }

  describe "#cost_label" do
    it "names the standard cost when there is no override" do
      expect(build_stubbed(:membership, cost_cents: nil).decorate.cost_label)
        .to eq("Standard (#{standard_cost})")
    end

    it "names the locked cost when there is one" do
      expect(build_stubbed(:membership, cost_cents: 1_500).decorate.cost_label).to eq("Locked at $15")
    end

    it "treats a zero cost as locked, not standard" do
      expect(build_stubbed(:membership, cost_cents: 0).decorate.cost_label).to eq("Locked at $0")
    end
  end

  describe "#auto_renewal_label" do
    it "reads on when renewal is on" do
      expect(build_stubbed(:membership).decorate.auto_renewal_label).to eq("on")
    end

    it "reads off when renewal is off" do
      expect(build_stubbed(:membership, :renewal_off).decorate.auto_renewal_label).to eq("off")
    end
  end

  describe "#status_label" do
    it "reads Upcoming for a membership whose term starts in the future" do
      membership = build_stubbed(:membership, start_date: Date.current + 1.month, end_date: Date.current + 1.year)

      expect(membership.decorate.status_label).to eq("Upcoming")
      expect(membership.decorate.status_classes).to include("blue")
    end
  end

  describe "#coverage_label and #coverage_date" do
    it "points at the end date while the membership is active" do
      membership = build_stubbed(:membership, start_date: Date.current - 1.month, end_date: Date.current + 11.months).decorate

      expect(membership.coverage_label).to eq("Membership good through:")
      expect(membership.coverage_date).to eq(Date.current + 11.months)
    end

    it "points at the start date when the membership has not begun" do
      membership = build_stubbed(:membership, start_date: Date.current + 1.month, end_date: Date.current + 13.months).decorate

      expect(membership.coverage_label).to eq("Membership starts:")
      expect(membership.coverage_date).to eq(Date.current + 1.month)
    end

    it "points at the end date once the membership has ended" do
      membership = build_stubbed(:membership, start_date: Date.current - 2.years, end_date: Date.current - 1.year).decorate

      expect(membership.coverage_label).to eq("Membership ended:")
      expect(membership.coverage_date).to eq(Date.current - 1.year)
    end
  end
end
