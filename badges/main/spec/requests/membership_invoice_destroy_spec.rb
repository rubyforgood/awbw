require "rails_helper"

RSpec.describe "Membership invoice deletion", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :without_audit) }
  let(:membership) do
    create(:membership, person: person,
      start_date: Date.current, end_date: Date.current + 2.years - 1.day)
  end

  before { sign_in admin }

  def invoice_for(start_date)
    create(:membership_invoice, membership: membership,
      start_date: start_date, end_date: start_date + Membership::INVOICE_PERIOD - 1.day)
  end

  it "deletes an invoice through the invoice resource" do
    past = invoice_for(Date.current - 1.year)
    invoice_for(Date.current)
    invoice_for(Date.current + 1.year)

    expect { delete membership_invoice_path(past) }
      .to change(MembershipInvoice, :count).by(-1)

    expect(response).to redirect_to(membership_path(membership))
    expect(flash[:notice]).to eq("Membership invoice deleted.")
  end

  it "removes the next year through the next-year resource" do
    current = invoice_for(Date.current)
    future = invoice_for(Date.current + 1.year)

    expect { delete membership_next_year_path(membership) }
      .to change(MembershipInvoice, :count).by(-1)

    expect(MembershipInvoice.exists?(future.id)).to be(false)
    expect(membership.reload.end_date).to eq(current.end_date)
    expect(membership).not_to be_renewal_on
    expect(response).to redirect_to(membership_path(membership))
    expect(flash[:notice]).to eq("Next year removed. Renewal and automatic payments are off.")
  end

  it "refuses to delete while an autopay attempt is pending" do
    past = invoice_for(Date.current - 1.year)
    invoice_for(Date.current)
    invoice_for(Date.current + 1.year)
    past.charge_attempts.create!(
      attempt_number: 1,
      status: "pending",
      amount_cents: past.cost_cents,
      attempted_at: 5.minutes.ago
    )

    expect { delete membership_invoice_path(past) }
      .not_to change(MembershipInvoice, :count)

    expect(response).to redirect_to(membership_path(membership))
    expect(flash[:alert]).to match(/payment is in progress/)
  end

  it "points the next-year invoice at the next-year resource" do
    invoice_for(Date.current)
    future = invoice_for(Date.current + 1.year)

    get membership_invoice_path(future)

    expect(response.body).to include(membership_next_year_path(membership))
  end

  it "denies removing the next year on a locked membership" do
    invoice_for(Date.current)
    future = invoice_for(Date.current + 1.year)
    membership.update_column(:locked_at, Time.current)

    delete membership_next_year_path(membership)

    expect(response).to redirect_to(root_path)
    expect(MembershipInvoice.exists?(future.id)).to be(true)
  end
end
