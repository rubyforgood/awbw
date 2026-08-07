require "rails_helper"

RSpec.describe "MembershipInvoices", type: :request do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership::ANNUAL_COST_CENTS) }
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:admin) { create(:user, :admin) }

  def term_for(name, cost_cents: Membership::ANNUAL_COST_CENTS, start_date: Date.current)
    person = create(:person, first_name: name, last_name: "Tester")
    create(:membership_invoice,
      membership: create(:membership, person: person),
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  describe "GET /membership_invoices" do
    it "is not available to a signed-out visitor" do
      get membership_invoices_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get membership_invoices_path

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      let(:frame) { { "Turbo-Frame" => "membership_invoices_results" } }

      it "renders the page with the lazy results frame" do
        get membership_invoices_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("membership_invoices_results")
      end

      it "lists each membership invoice with its person, invoice and cost in the frame" do
        term_for("Ada")

        get membership_invoices_path, headers: frame

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ada Tester")
        expect(response.body).to include(standard_cost)
      end

      it "shows the status badge for an overdue year" do
        term_for("Behind", start_date: Date.current - Membership::GRACE_PERIOD_DAYS - 1)

        get membership_invoices_path, headers: frame

        expect(response.body).to include("Overdue")
      end

      it "notes a cancelled subscription" do
        invoice = term_for("Gone")
        invoice.membership.update!(cancelled_at: Time.current)

        get membership_invoices_path, headers: frame

        expect(response.body).to include("Subscription cancelled")
      end

      it "says so when there are none" do
        get membership_invoices_path, headers: frame

        expect(response.body).to include("No membership invoices yet")
      end
    end
  end

  describe "GET /membership_invoices/:id" do
    let(:invoice) { term_for("Ada") }

    it "is not available to a non-admin" do
      sign_in create(:user)
      get membership_invoice_path(invoice)

      expect(response).to redirect_to(root_path)
    end

    it "redirects to the person's membership page, giving an invoice a canonical URL" do
      sign_in admin
      get membership_invoice_path(invoice)

      expect(response).to redirect_to(person_memberships_path(invoice.registrant))
    end
  end

  describe "the status pill" do
    before { sign_in admin }

    it "links to the year's scoped allocations page from the index" do
      invoice = term_for("Ada")

      get membership_invoices_path, headers: { "Turbo-Frame" => "membership_invoices_results" }

      expect(response.body).to include(allocations_path(allocatable_sgid: invoice.to_sgid.to_s))
    end
  end

  describe "GET /memberships/:id/membership_invoices/new" do
    let(:subscription) { create(:membership, person: create(:person)) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      get new_membership_membership_invoice_path(subscription)

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "starts today for a subscription with no years" do
        get new_membership_membership_invoice_path(subscription)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(Date.current.to_s)
      end

      it "starts the day after the latest year for a subscription that has one" do
        create(:membership_invoice, membership: subscription,
          start_date: Date.new(2026, 10, 14), end_date: Date.new(2027, 10, 13))

        get new_membership_membership_invoice_path(subscription)

        expect(response.body).to include("2027-10-14")
      end

      it "prefills the cost from a locked cost" do
        subscription.update!(cost_cents: 1_500)

        get new_membership_membership_invoice_path(subscription)

        expect(response.body).to include("15.0")
      end
    end
  end

  describe "POST /memberships/:id/membership_invoices" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }
    let(:valid_params) do
      { membership_invoice: { start_date: Date.current.to_s, cost_dollars: "25" } }
    end

    it "is not available to a non-admin" do
      sign_in create(:user)

      expect { post membership_membership_invoices_path(subscription), params: valid_params }
        .not_to change(MembershipInvoice, :count)
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "adds the year and derives its end date" do
        expect { post membership_membership_invoices_path(subscription), params: valid_params }
          .to change(MembershipInvoice, :count).by(1)

        year = subscription.membership_invoices.sole
        expect(year.start_date).to eq(Date.current)
        expect(year.end_date).to eq(Date.current + 1.year - 1.day)
        expect(year.cost_cents).to eq(2_500)
        expect(response).to redirect_to(person_memberships_path(person))
      end

      it "adds a year to a cancelled subscription" do
        subscription.update!(cancelled_at: Time.current)

        expect { post membership_membership_invoices_path(subscription), params: valid_params }
          .to change(MembershipInvoice, :count).by(1)
      end

      it "rejects a year overlapping an existing one" do
        create(:membership_invoice, membership: subscription,
          start_date: Date.current, end_date: Date.current + 1.year - 1.day)

        expect { post membership_membership_invoices_path(subscription), params: valid_params }
          .not_to change(MembershipInvoice, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("overlapping")
      end
    end
  end

  describe "PATCH /membership_invoices/:id" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }
    let!(:year) do
      create(:membership_invoice, membership: subscription,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day, cost_cents: 2_500)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch membership_invoice_path(year), params: { membership_invoice: { cost_dollars: "5" } }

      expect(response).to redirect_to(root_path)
      expect(year.reload.cost_cents).to eq(2_500)
    end

    context "as an admin" do
      before { sign_in admin }

      it "corrects the dates and cost" do
        patch membership_invoice_path(year), params: {
          membership_invoice: {
            start_date: Date.current.to_s,
            end_date: (Date.current + 30.days).to_s,
            cost_dollars: "10"
          }
        }

        year.reload
        expect(year.end_date).to eq(Date.current + 30.days)
        expect(year.cost_cents).to eq(1_000)
        expect(response).to redirect_to(person_memberships_path(person))
      end

      it "accepts a cost of zero" do
        patch membership_invoice_path(year), params: { membership_invoice: { cost_dollars: "0" } }

        expect(year.reload.cost_cents).to eq(0)
      end

      it "refuses a cost below what has already been paid" do
        create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: year, amount: 2_500)

        patch membership_invoice_path(year), params: { membership_invoice: { cost_dollars: "5" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(year.reload.cost_cents).to eq(2_500)
        expect(response.body).to include("already allocated")
      end

      it "refuses an end date before the start" do
        patch membership_invoice_path(year), params: {
          membership_invoice: { end_date: (Date.current - 1.day).to_s }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
