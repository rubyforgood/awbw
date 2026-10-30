require "rails_helper"

RSpec.describe "Membership invoice attempt warnings", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, :without_audit) }
  let(:membership) { create(:membership, person: person) }

  before { sign_in admin }

  def invoice_with_attempt(paid: false)
    invoice = create(:membership_invoice, membership: membership, cost_cents: 2_500,
      start_date: Date.current, end_date: Date.current + 1.year - 1.day)
    invoice.charge_attempts.create!(
      attempt_number: 1,
      status: "failed",
      amount_cents: 2_500,
      attempted_at: Time.current,
      error_message: "Your card was declined."
    )

    if paid
      create(:allocation, source: create(:payment, amount_cents: 2_500),
        allocatable: invoice, amount: 2_500)
    end

    invoice
  end

  def get_results
    get membership_invoices_path, headers: { "Turbo-Frame" => "membership_invoices_results" }
  end

  it "shows the latest attempt error while the invoice still has a balance" do
    invoice_with_attempt

    get_results

    expect(response.body).to include("Your card was declined.")
  end

  it "hides the latest attempt error once the invoice is paid" do
    invoice_with_attempt(paid: true)

    get_results

    expect(response.body).not_to include("Your card was declined.")
  end
end
