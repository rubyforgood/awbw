require "rails_helper"

RSpec.describe Membership::Create do
  let(:person) { create(:person, :without_user) }

  def create_membership(**options)
    described_class.call(person: person, start_date: Date.current, **options)
  end

  def invoice_for(result)
    result.membership.membership_invoices.sole
  end

  it "bills the standard cost when no price is locked" do
    result = create_membership

    expect(result).to be_success
    expect(invoice_for(result).cost_cents).to eq(Membership.annual_cost_cents)
  end

  it "bills the locked price for the first invoice by default" do
    result = create_membership(cost_cents: 1_500)

    expect(result.membership.cost_cents).to eq(1_500)
    expect(invoice_for(result).cost_cents).to eq(1_500)
  end

  it "lets the first invoice override the locked price" do
    result = create_membership(cost_cents: 1_500, invoice_cost_cents: 2_500)

    expect(result.membership.cost_cents).to eq(1_500)
    expect(invoice_for(result).cost_cents).to eq(2_500)
  end

  it "keeps a comped first invoice at zero" do
    result = create_membership(cost_cents: 1_500, invoice_cost_cents: 0)

    expect(invoice_for(result).cost_cents).to eq(0)
  end
end
