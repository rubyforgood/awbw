require "rails_helper"

RSpec.describe Membership::UpdateTerm do
  let(:person) { create(:person, :without_user) }

  def create_membership(start_date:, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
    create(:membership, person: person, start_date: start_date, end_date: end_date)
  end

  def invoice_for(membership, start_date, end_date:, cost_cents: Membership.annual_cost_cents)
    create(:membership_invoice, membership: membership, cost_cents: cost_cents,
      start_date: start_date, end_date: end_date)
  end

  def pay(invoice)
    create(:allocation, source: create(:payment, amount_cents: invoice.cost_cents),
      allocatable: invoice, amount: invoice.cost_cents)
    invoice.reload
  end

  def update(membership, end_date:, start_date: membership.start_date)
    described_class.call(membership: membership, start_date: start_date,
      end_date: end_date, cost_cents: membership.cost_cents)
  end

  it "ends the term early and leaves the current invoice untouched" do
    membership = create_membership(start_date: Date.current)
    current = pay(invoice_for(membership, Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day))

    result = update(membership, end_date: Date.current + 1.month)

    expect(result).to be_success
    expect(membership.reload.end_date).to eq(Date.current + 1.month)
    expect(membership).not_to be_renewal_on
    expect(current.reload).to have_attributes(
      start_date: Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day,
      cost_cents: Membership.annual_cost_cents
    )
    expect(current).to be_paid_in_full
  end

  it "leaves a paid next-year invoice in place" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    pay(invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day))
    future = pay(invoice_for(membership, Date.current + 1.year,
      end_date: Date.current + 2.years - 1.day))

    result = update(membership, end_date: Date.current + 1.month)

    expect(result).to be_success
    expect(membership.reload.end_date).to eq(Date.current + 1.month)
    expect(future.reload).to be_paid_in_full
    expect(future).to be_persisted
  end

  it "destroys an unstarted unpaid next-year invoice" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day)
    future = invoice_for(membership, Date.current + 1.year,
      end_date: Date.current + 2.years - 1.day)

    expect { update(membership, end_date: Date.current + 1.month) }
      .to change(MembershipInvoice, :count).by(-1)

    expect(MembershipInvoice.exists?(future.id)).to be(false)
    expect(membership.reload.end_date).to eq(Date.current + 1.month)
  end

  it "keeps an unpaid next-year invoice when its period overlaps the new term" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day)
    future = invoice_for(membership, Date.current + 1.year,
      end_date: Date.current + 2.years - 1.day)

    result = update(membership, end_date: Date.current + 1.year + 1.month)

    expect(result).to be_success
    expect(future.reload).to be_persisted
    expect(future).not_to be_paid_in_full
  end

  it "rejects extending the term beyond the last invoice" do
    membership = create_membership(start_date: Date.current)
    invoice_for(membership, Date.current, end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    result = update(membership, end_date: Date.current + Membership::INVOICE_PERIOD)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/last invoice/)
    expect(membership.reload.end_date).to eq(Date.current + Membership::INVOICE_PERIOD - 1.day)
  end

  it "allows extending the term within the issued invoice" do
    membership = create_membership(start_date: Date.current, end_date: Date.current + 1.month)
    invoice_for(membership, Date.current, end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    result = update(membership, end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    expect(result).to be_success
    expect(membership.reload.end_date).to eq(Date.current + Membership::INVOICE_PERIOD - 1.day)
  end

  it "refuses to remove a next-year invoice while a payment is in progress" do
    membership = create_membership(start_date: Date.current,
      end_date: Date.current + 2.years - 1.day)
    invoice_for(membership, Date.current, end_date: Date.current + 1.year - 1.day)
    future = invoice_for(membership, Date.current + 1.year,
      end_date: Date.current + 2.years - 1.day)
    future.mark_payment_in_progress!

    result = update(membership, end_date: Date.current + 1.month)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/payment is in progress/)
    expect(future.reload).to be_persisted
  end
end
