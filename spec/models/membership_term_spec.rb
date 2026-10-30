require "rails_helper"

RSpec.describe "Membership term", type: :model do
  let(:person) { create(:person) }

  def create_membership(start_date: Date.current, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
    create(:membership, person: person, start_date: start_date, end_date: end_date)
  end

  def invoice_for(membership, start_date, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
    create(:membership_invoice, membership: membership, start_date: start_date, end_date: end_date)
  end

  describe "term coverage" do
    let(:membership) { create_membership(start_date: Date.current - 1.year, end_date: Date.current + 1.year - 1.day) }

    before do
      invoice_for(membership, Date.current - 1.year, end_date: Date.current - 1.day)
      invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day)
    end

    it "allows the term to be shorter than the invoices" do
      expect(membership.update(end_date: Date.current - 1.day)).to be(true)
    end

    it "rejects an end date beyond the last invoice" do
      expect(membership.update(end_date: Date.current + 1.year)).to be(false)
      expect(membership.errors[:end_date].join).to match(/last invoice/)
    end

    it "rejects a start date before the first invoice" do
      expect(membership.update(start_date: Date.current - 1.year - 1.day)).to be(false)
      expect(membership.errors[:start_date].join).to match(/first invoice/)
    end

    it "reports the invoice coverage range" do
      expect(membership.invoice_coverage_start).to eq(Date.current - 1.year)
      expect(membership.invoice_coverage_end).to eq(Date.current + 1.year - 1.day)
    end
  end

  describe "overlap" do
    let!(:existing) { create_membership }

    it "rejects a membership starting on the same day the previous one ends" do
      other = build(:membership, person: person,
        start_date: existing.end_date, end_date: existing.end_date + Membership::INVOICE_PERIOD - 1.day)

      expect(other).not_to be_valid
      expect(other.errors[:base].join).to match(/overlaps/)
    end

    it "allows a membership starting the day after" do
      other = build(:membership, person: person,
        start_date: existing.end_date + 1.day,
        end_date: existing.end_date + Membership::INVOICE_PERIOD)

      expect(other).to be_valid
    end
  end

  describe "#renewal_blocked_reason" do
    it "allows renewal when the term reaches the last invoice and is current" do
      membership = create_membership
      invoice_for(membership, membership.start_date, end_date: membership.end_date)

      expect(membership.renewal_blocked_reason).to be_nil
    end

    it "blocks an ended term beyond the one-day grace" do
      membership = create_membership
      invoice_for(membership, membership.start_date, end_date: membership.end_date)
      membership.update_columns(end_date: Date.current - 2.days)

      expect(membership.renewal_blocked_reason).to match(/ended on/)
    end

    it "blocks when an invoice covers past the term" do
      membership = create_membership
      invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day)
      invoice_for(membership, Date.current + 1.year, end_date: Date.current + 2.years - 1.day)

      expect(membership.renewal_blocked_reason).to match(/An invoice covers through/)
    end

    it "blocks a membership with no invoices" do
      membership = create_membership

      expect(membership.renewal_blocked_reason).to match(/no invoices/)
    end
  end

  describe "invoice deletion" do
    let(:membership) { create_membership(start_date: Date.current - 1.year, end_date: Date.current + 1.year - 1.day) }
    let!(:first) { invoice_for(membership, Date.current - 1.year, end_date: Date.current - 1.day) }
    let!(:last) { invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day) }

    it "shrinks the term when the last invoice is deleted" do
      last.destroy!

      expect(membership.reload.end_date).to eq(first.end_date)
      expect(membership.start_date).to eq(first.start_date)
    end
  end
end
