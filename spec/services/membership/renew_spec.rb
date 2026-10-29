require "rails_helper"

RSpec.describe Membership::Renew do
  let(:person) { create(:person) }

  def create_membership(end_date:, cost_cents: nil)
    create(:membership, person: person,
      start_date: end_date - Membership::INVOICE_PERIOD + 1.day,
      end_date: end_date,
      cost_cents: cost_cents)
  end

  def invoice_for(membership, start_date: membership.start_date, end_date: membership.end_date)
    create(:membership_invoice, membership: membership,
      cost_cents: membership.cost_cents || Membership.annual_cost_cents,
      start_date: start_date, end_date: end_date)
  end

  def pay(invoice)
    create(:allocation, source: create(:payment, amount_cents: invoice.cost_cents),
      allocatable: invoice, amount: invoice.cost_cents)
    invoice.reload
  end

  it "creates the next invoice after the last one and extends the term" do
    end_date = Date.current + 10.days
    membership = create_membership(end_date: end_date, cost_cents: 1_500)
    invoice = pay(invoice_for(membership))

    result = described_class.call(membership: membership)

    expect(result).to be_success
    expect(result.invoice.start_date).to eq(invoice.end_date + 1.day)
    expect(result.invoice.end_date).to eq(invoice.end_date + Membership::INVOICE_PERIOD)
    expect(result.invoice.cost_cents).to eq(1_500)
    expect(membership.reload.end_date).to eq(result.invoice.end_date)
  end

  it "refuses when the term ends before its invoice coverage" do
    membership = create_membership(end_date: Date.current + 10.days)
    pay(invoice_for(membership, start_date: membership.start_date,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day))

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/Extend the term first/)
  end

  it "refuses a term that ended more than a day ago" do
    membership = create_membership(end_date: Date.current - 2.days)
    pay(invoice_for(membership))

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/already ended/)
  end

  it "refuses when renewal is turned off" do
    membership = create_membership(end_date: Date.current + 10.days)
    membership.update_column(:autorenewal_cancelled_at, Time.current)
    pay(invoice_for(membership))

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/Renewal is turned off/)
  end

  it "refuses an unsettled ending invoice" do
    membership = create_membership(end_date: Date.current + 10.days)
    invoice_for(membership)

    result = described_class.call(membership: membership)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/not settled/)
  end

  it "only bypasses the renewal window when forced" do
    membership = create_membership(end_date: Date.current + 1.year - 1.day)
    pay(invoice_for(membership))

    too_early = described_class.call(membership: membership)
    expect(too_early).not_to be_success
    expect(too_early.errors.to_sentence).to match(/renewal window/)

    expect(described_class.call(membership: membership, force: true)).to be_success
  end

  it "still refuses a coverage mismatch when forced" do
    membership = create_membership(end_date: Date.current + 1.month)
    pay(invoice_for(membership, start_date: membership.start_date,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day))

    result = described_class.call(membership: membership, force: true)

    expect(result).not_to be_success
    expect(result.errors.to_sentence).to match(/Extend the term first/)
  end
end
