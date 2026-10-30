require "rails_helper"

RSpec.describe Membership::RemoveNextYear do
  let(:person) { create(:person, :without_user) }

  def create_membership(start_date:, end_date:)
    create(:membership, person: person, start_date: start_date, end_date: end_date)
  end

  def invoice_for(membership, start_date:)
    create(:membership_invoice, membership: membership,
      start_date: start_date, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
  end

  it "removes the next year, turns renewal off, and shrinks the term" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    current = invoice_for(membership, start_date: Date.current)
    future = invoice_for(membership, start_date: Date.current + 1.year)

    result = described_class.call(membership: membership)

    expect(result).to be_success
    expect(MembershipInvoice.exists?(future.id)).to be(false)
    expect(membership.reload.end_date).to eq(current.end_date)
    expect(membership).not_to be_renewal_on
  end

  it "refuses when the next year already has payments" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, start_date: Date.current)
    future = invoice_for(membership, start_date: Date.current + 1.year)
    create(:allocation, source: create(:payment, amount_cents: 100), allocatable: future, amount: 100)

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/payments applied/)
    expect(future.reload).to be_persisted
  end

  it "refuses when the next year is the only invoice" do
    membership = create_membership(start_date: Date.current + 1.year,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, start_date: Date.current + 1.year)

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/only invoice/)
  end

  it "refuses while a payment is in progress" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, start_date: Date.current)
    future = invoice_for(membership, start_date: Date.current + 1.year)
    future.mark_payment_in_progress!

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/payment is in progress/)
    expect(future.reload).to be_persisted
  end
end
