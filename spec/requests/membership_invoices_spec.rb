require "rails_helper"

RSpec.describe "MembershipInvoices", type: :request do
  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership.annual_cost_cents) }
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:admin) { create(:user, :admin) }

  def term_for(name, cost_cents: Membership.annual_cost_cents, start_date: Date.current)
    person = create(:person, first_name: name, last_name: "Tester")
    create(:membership_invoice,
      membership: create(:membership, person: person),
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  describe "GET /membership_invoices/:id" do
    let(:subscription) { create(:membership, person: create(:person, first_name: "Renewal")) }
    let!(:earlier) do
      create(:membership_invoice, membership: subscription,
        start_date: Date.current - 2.years, end_date: Date.current - 1.year - 1.day)
    end
    let(:invoice) do
      create(:membership_invoice, membership: subscription,
        start_date: Date.current + 1.year, end_date: Date.current + 2.years - 1.day)
    end

    before { sign_in admin }

    it_behaves_like "a page with a change log" do
      let(:record) { invoice }
      let(:page_path) { membership_invoice_path(invoice) }
    end

    it "renders the invoice" do
      get membership_invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(invoice.decorate.period_range)
    end

    it "offers deleting the invoice" do
      get membership_invoice_path(invoice)

      expect(response.body).to include("Delete invoice")
    end

    it "explains why an invoice can't be deleted" do
      current = term_for("Covered")

      get membership_invoice_path(current)

      expect(response.body).to include("it covers today")
      expect(response.body).not_to include("Delete invoice")
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get membership_invoice_path(invoice)

      expect(response).to redirect_to(root_path)
    end
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
        term_for("Behind", start_date: 60.days.ago)

        get membership_invoices_path, headers: frame

        expect(response.body).to include("Overdue")
      end

      it "notes a cancelled subscription" do
        invoice = term_for("Gone")
        invoice.membership.update!(autorenewal_cancelled_at: Time.current)

        get membership_invoices_path, headers: frame

        expect(response.body).to include("Membership renewals stopped")
      end

      it "says so when there are none" do
        get membership_invoices_path, headers: frame

        expect(response.body).to include("No membership invoices yet")
      end

      it "renders the person-name filter box on the index" do
        get membership_invoices_path

        expect(response.body).to include("person_name")
      end

      it "filters the frame results by person name" do
        term_for("Ada")
        term_for("Grace")

        get membership_invoices_path(person_name: "Ada"), headers: frame

        expect(response.body).to include("Ada Tester")
        expect(response.body).not_to include("Grace Tester")
      end
    end
  end

  describe "the status pill" do
    before { sign_in admin }

    it "links to the year's scoped allocations page from the index" do
      invoice = term_for("Ada")

      get membership_invoices_path, headers: { "Turbo-Frame" => "membership_invoices_results" }

      # The page renders in the viewer's zone (ApplicationController#set_time_zone_from_user),
      # and GlobalID signs a 1-month expiry into the sgid — so sign the expectation in the same
      # zone or the DST-crossing month can land on a different instant.
      expected = Time.use_zone(admin.time_zone) do
        allocations_path(allocatable_sgid: invoice.to_sgid.to_s)
      end
      expect(response.body).to include(expected)
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
        subscription.update!(autorenewal_cancelled_at: Time.current)

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

      it "syncs the Stripe price when the new year starts later" do
        expect {
          post membership_membership_invoices_path(subscription), params: {
            membership_invoice: { start_date: (Date.current + 1.year).to_s, cost_dollars: "25" }
          }
        }.to have_enqueued_job(SyncMembershipSubscriptionPriceJob).with(subscription.id)
      end

      it "hands the job the membership the invoice belongs to" do
        allow(Membership::SyncSubscriptionPrice).to receive(:call)

        perform_enqueued_jobs do
          post membership_membership_invoices_path(subscription), params: {
            membership_invoice: { start_date: (Date.current + 1.year).to_s, cost_dollars: "25" }
          }
        end

        expect(Membership::SyncSubscriptionPrice).to have_received(:call).with(membership: subscription)
      end

      it "doesn't sync a year that starts today" do
        expect {
          post membership_membership_invoices_path(subscription), params: valid_params
        }.not_to have_enqueued_job(SyncMembershipSubscriptionPriceJob)
      end
    end
  end

  describe "DELETE /membership_invoices/:id" do
    let(:person) { create(:person) }
    let(:subscription) { create(:membership, person: person) }

    def invoice(start_date)
      create(:membership_invoice, membership: subscription,
        start_date: start_date, end_date: start_date + 1.year - 1.day)
    end

    it "is not available to a non-admin" do
      record = invoice(Date.current + 1.day)
      sign_in create(:user)

      expect { delete membership_invoice_path(record) }.not_to change(MembershipInvoice, :count)
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "deletes an unpaid invoice when another invoice remains" do
        invoice(Date.current - 2.years)
        record = invoice(Date.current + 1.day)

        expect { delete membership_invoice_path(record) }.to change(MembershipInvoice, :count).by(-1)
        expect(response).to redirect_to(person_memberships_path(person))
        expect(flash[:notice]).to eq("Membership invoice deleted.")
      end

      it "refuses to delete the membership's only invoice" do
        record = invoice(Date.current + 1.day)

        expect { delete membership_invoice_path(record) }.not_to change(MembershipInvoice, :count)
        expect(response).to redirect_to(person_memberships_path(person))
        expect(flash[:alert]).to match(/only invoice/)
      end

      it "refuses to delete an invoice with payments" do
        invoice(Date.current - 2.years)
        record = invoice(Date.current + 1.day)
        create(:allocation, source: create(:payment, amount_cents: 100), allocatable: record, amount: 100)

        expect { delete membership_invoice_path(record) }.not_to change(MembershipInvoice, :count)
        expect(flash[:alert]).to match(/payments or credits/)
      end
    end
  end

  describe "GET /membership_invoices/:id/receipt" do
    let(:person) { create(:person, first_name: "Ada", last_name: "Lovelace") }
    let(:membership) { create(:membership, person: person) }
    let!(:invoice) { create(:membership_invoice, membership: membership, cost_cents: 2_500) }

    def settle(amount: 2_500)
      create(:allocation, source: create(:payment, amount_cents: amount), allocatable: invoice, amount: amount)
    end

    before { sign_in admin }

    it "is not available to a non-admin" do
      sign_in create(:user)

      get receipt_membership_invoice_path(invoice)

      expect(response).to redirect_to(root_path)
    end

    it "sends the viewer back to the invoice until the year is paid in full" do
      get receipt_membership_invoice_path(invoice)

      expect(response).to redirect_to(membership_invoice_path(invoice))
      expect(flash[:alert]).to match(/paid in full/)
    end

    it "renders the receipt once a payment settles the year" do
      settle

      get receipt_membership_invoice_path(invoice)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("RECEIPT")
      expect(response.body).to include("MR-#{invoice.id}")
      expect(response.body).to include("Ada Lovelace")
      expect(response.body).to include("AWBW annual membership")
      expect(response.body).to include("$25")
      expect(response.body).to include("Balance due")
    end

    it "lets the owning member view their receipt" do
      settle
      sign_in create(:user, person: person)

      get receipt_membership_invoice_path(invoice)

      expect(response).to have_http_status(:ok)
    end
  end
end
