require "rails_helper"

RSpec.describe Membership, type: :model do
  describe "validations" do
    it "allows a nil cost_cents, meaning the standard cost" do
      expect(build(:membership, cost_cents: nil)).to be_valid
    end

    it "allows a zero cost_cents, meaning a comped member" do
      expect(build(:membership, cost_cents: 0)).to be_valid
    end

    it "rejects a negative cost_cents" do
      membership = build(:membership, cost_cents: -1)
      expect(membership).not_to be_valid
      expect(membership.errors[:cost_cents]).to be_present
    end

    it "rejects end_date before start_date" do
      membership = build(:membership, start_date: Date.current + 1.month, end_date: Date.current)
      expect(membership).not_to be_valid
      expect(membership.errors[:end_date]).to be_present
    end

    it "rejects overlapping dates with an existing membership for the same person" do
      person = create(:person, :without_user)
      create(:membership, :renewal_off, person: person,
        start_date: Date.current - 1.month, end_date: Date.current + 1.month)

      overlap = build(:membership, person: person, start_date: Date.current, end_date: Date.current + 2.months)
      expect(overlap).not_to be_valid
      expect(overlap.errors[:base].join).to match(/overlaps/)
    end

    it "allows a new membership with non-overlapping dates when the previous is renewal off" do
      person = create(:person, :without_user)
      create(:membership, :renewal_off, person: person,
        start_date: Date.current - 2.months, end_date: Date.current - 1.month)

      expect(build(:membership, person: person, start_date: Date.current, end_date: Date.current + 1.month)).to be_valid
    end
  end

  describe "scopes" do
    it "renewal_on excludes renewal-off memberships" do
      open_membership = create(:membership)
      create(:membership, :renewal_off)

      expect(described_class.renewal_on).to contain_exactly(open_membership)
    end
  end

  describe "#active?" do
    it "is true when end_date is in the future" do
      expect(create(:membership, end_date: Date.current + 1.month)).to be_active
    end

    it "is false when end_date is in the past" do
      expect(create(:membership, start_date: Date.current - 2.months, end_date: Date.current - 1.month)).not_to be_active
    end
  end

  describe "#upcoming?" do
    it "is true when the start date is in the future" do
      membership = create(:membership, start_date: Date.current + 1.month, end_date: Date.current + 1.year)

      expect(membership).to be_upcoming
    end

    it "is false while the membership is active, even with a future invoice" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)

      expect(membership.reload).not_to be_upcoming
    end
  end

  describe "associations" do
    it "is reachable from the person, along with their invoices" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership)

      expect(membership.person.memberships).to contain_exactly(membership)
      expect(membership.person.membership_invoices).to contain_exactly(invoice)
    end
  end

  describe "#next_autopay_invoice" do
    it "returns an unpaid invoice within the renewal window" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      expect(membership.next_autopay_invoice).to eq(invoice)
    end

    it "ignores an invoice beyond the renewal window" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership,
        start_date: Date.current + Membership.renewal_window_days + 1.day,
        end_date: Date.current + Membership.renewal_window_days + 1.year)

      expect(membership.next_autopay_invoice).to be_nil
    end
  end

  describe "#owes?" do
    it "is true when a started invoice still has a balance" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      expect(membership).to be_owes
    end

    it "is false when the started invoice is paid in full" do
      membership = create(:membership)
      invoice = create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)
      create(:allocation, source: create(:payment, amount_cents: 2_500),
        allocatable: invoice, amount: 2_500)

      expect(membership.reload).not_to be_owes
    end

    it "is false for a comped invoice" do
      membership = create(:membership)
      create(:membership_invoice, :comped, membership: membership,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day)

      expect(membership).not_to be_owes
    end

    it "is false for an invoice that has not started yet" do
      membership = create(:membership)
      create(:membership_invoice, membership: membership, cost_cents: 2_500,
        start_date: Date.current + 1.day, end_date: Date.current + 1.year)

      expect(membership).not_to be_owes
    end
  end
end
