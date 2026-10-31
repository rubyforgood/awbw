require "rails_helper"

RSpec.describe "Membership renewal", type: :request do
  around { |example| Time.use_zone("Pacific Time (US & Canada)") { example.run } }

  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :without_audit) }

  before { sign_in admin }

  def create_membership(end_date: Date.current + 10.days)
    create(:membership, person: person,
      start_date: end_date - Membership::INVOICE_PERIOD + 1.day,
      end_date: end_date)
  end

  def invoice_for(membership, end_date: membership.end_date)
    create(:membership_invoice, membership: membership,
      start_date: membership.start_date, end_date: end_date)
  end

  it "turns renewal on when the term reaches the last invoice" do
    membership = create_membership
    membership.update_column(:renewal_off_at, Time.current)
    invoice_for(membership)

    patch membership_renewal_path(membership), params: { renewal_on: "1" }

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload).to be_renewal_on
  end

  it "turns renewal off without a guard" do
    membership = create_membership
    invoice_for(membership)

    patch membership_renewal_path(membership), params: { renewal_on: "0" }

    expect(response).to redirect_to(membership_path(membership))
    expect(membership.reload).not_to be_renewal_on
  end

  it "refuses to turn renewal on when an invoice covers past the term" do
    membership = create_membership(end_date: Date.current + 1.month)
    membership.update_column(:renewal_off_at, Time.current)
    invoice_for(membership, end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    patch membership_renewal_path(membership), params: { renewal_on: "1" }

    expect(response).to redirect_to(membership_path(membership))
    expect(flash[:alert]).to match(/An invoice covers through/)
    expect(membership.reload).not_to be_renewal_on
  end

  it "refuses to turn renewal on for a long-ended term" do
    membership = create_membership(end_date: Date.current - 2.days)
    membership.update_column(:renewal_off_at, Time.current)
    invoice_for(membership)

    patch membership_renewal_path(membership), params: { renewal_on: "1" }

    expect(flash[:alert]).to match(/ended on/)
    expect(membership.reload).not_to be_renewal_on
  end

  it "shows the blocked reason and a disabled toggle" do
    membership = create_membership(end_date: Date.current + 1.month)
    membership.update_column(:renewal_off_at, Time.current)
    invoice_for(membership, end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    get membership_path(membership)

    expect(response.body).to include("An invoice covers through")
    expect(response.body).to include("Turn on renewal")
  end
end
