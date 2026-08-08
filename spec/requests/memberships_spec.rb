require "rails_helper"

RSpec.describe "Memberships", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Membership::ANNUAL_COST_CENTS) }
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Grace", last_name: "Hopper") }

  def membership_invoice_for(subscription:, cost_cents: Membership::ANNUAL_COST_CENTS, start_date: Date.current)
    create(:membership_invoice,
      membership: subscription,
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  describe "GET /people/:person_id/memberships" do
    it "is not available to a signed-out visitor" do
      get person_memberships_path(person)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get person_memberships_path(person)

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "names the person and links back to their profile" do
        get person_memberships_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Grace Hopper")
        expect(response.body).to include(person_path(person))
      end

      it "says so when there is no subscription" do
        get person_memberships_path(person)

        expect(response.body).to include("No membership yet")
      end

      it "lists every year of a subscription, newest first" do
        subscription = create(:membership, person: person)
        older = membership_invoice_for(subscription: subscription, cost_cents: 0, start_date: Date.current - 1.year)
        newer = membership_invoice_for(subscription: subscription)

        get person_memberships_path(person)

        body = response.body
        expect(body).to include(newer.decorate.period_range, older.decorate.period_range)
        expect(body.index(newer.decorate.period_range)).to be < body.index(older.decorate.period_range)
      end

      it "lists past subscriptions alongside the current one" do
        past = create(:membership, :cancelled, person: person, cost_cents: 1_500)
        membership_invoice_for(subscription: past, start_date: Date.current - 3.years)
        create(:membership, person: person)

        get person_memberships_path(person)

        expect(response.body).to include("Locked at $15")
        expect(response.body).to include("Standard (#{standard_cost})")
      end

      it "shows the status badge for each year" do
        subscription = create(:membership, person: person)
        membership_invoice_for(subscription: subscription, start_date: Date.current - Membership::GRACE_PERIOD_DAYS - 1)

        get person_memberships_path(person)

        expect(response.body).to include("Overdue")
      end

      it "says so when a subscription has no years" do
        create(:membership, person: person)

        get person_memberships_path(person)

        expect(response.body).to include("No membership invoices yet")
      end
    end
  end

  describe "GET /people/:person_id/memberships/new" do
    it "is not available to a non-admin" do
      sign_in create(:user)
      get new_person_membership_path(person)

      expect(response).to redirect_to(root_path)
    end

    it "prefills the first year at today and the standard cost" do
      sign_in admin
      get new_person_membership_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Date.current.to_s)
      expect(response.body).to include((Membership::ANNUAL_COST_CENTS / 100.0).to_s)
    end
  end

  describe "POST /people/:person_id/memberships" do
    let(:valid_params) do
      {
        membership: {
          cost_dollars: "",
          membership_invoices_attributes: {
            "0" => { start_date: Date.current.to_s, cost_dollars: (Membership::ANNUAL_COST_CENTS / 100).to_s }
          }
        }
      }
    end

    it "is not available to a non-admin" do
      sign_in create(:user)

      expect { post person_memberships_path(person), params: valid_params }
        .not_to change(Membership, :count)
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "creates the subscription and its first year together" do
        expect { post person_memberships_path(person), params: valid_params }
          .to change(Membership, :count).by(1)
          .and change(MembershipInvoice, :count).by(1)

        subscription = person.memberships.sole
        year = subscription.membership_invoices.sole
        expect(subscription.cost_cents).to be_nil
        expect(year.cost_cents).to eq(Membership::ANNUAL_COST_CENTS)
        expect(year.start_date).to eq(Date.current)
        expect(year.end_date).to eq(Date.current + 1.year - 1.day)
        expect(response).to redirect_to(person_memberships_path(person))
      end

      it "locks in a cost when one is given" do
        post person_memberships_path(person),
          params: valid_params.deep_merge(membership: { cost_dollars: "15" })

        expect(person.memberships.sole.cost_cents).to eq(1_500)
      end

      it "accepts a cost of zero for a year already covered" do
        post person_memberships_path(person),
          params: valid_params.deep_merge(
            membership: { membership_invoices_attributes: { "0" => { cost_dollars: "0" } } }
          )

        expect(person.membership_invoices.sole.cost_cents).to eq(0)
      end

      it "rejects a second uncancelled subscription" do
        create(:membership, person: person)

        expect { post person_memberships_path(person), params: valid_params }
          .not_to change(Membership, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("already has a membership")
      end

      it "rejects a year overlapping an existing one" do
        existing = create(:membership, :cancelled, person: person)
        create(:membership_invoice, membership: existing,
          start_date: Date.current, end_date: Date.current + 1.year - 1.day)

        expect { post person_memberships_path(person), params: valid_params }
          .not_to change(MembershipInvoice, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("overlapping")
      end

      it "rejects a missing start date" do
        post person_memberships_path(person),
          params: valid_params.deep_merge(
            membership: { membership_invoices_attributes: { "0" => { start_date: "" } } }
          )

        expect(response).to have_http_status(:unprocessable_content)
        expect(Membership.count).to eq(0)
      end
    end
  end

  describe "GET /memberships/:id/edit" do
    let(:subscription) { create(:membership, person: person, cost_cents: 1_500) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      get edit_membership_path(subscription)

      expect(response).to redirect_to(root_path)
    end

    it "shows the current cost and says it applies to future years" do
      sign_in admin
      get edit_membership_path(subscription)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("15.0")
      expect(response.body).to include("future membership invoices only")
    end
  end

  describe "PATCH /memberships/:id" do
    let!(:subscription) { create(:membership, person: person) }
    let!(:existing_year) do
      create(:membership_invoice, membership: subscription, cost_cents: Membership::ANNUAL_COST_CENTS)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch membership_path(subscription), params: { membership: { cost_dollars: "15" } }

      expect(response).to redirect_to(root_path)
      expect(subscription.reload.cost_cents).to be_nil
    end

    context "as an admin" do
      before { sign_in admin }

      it "locks in a new cost" do
        patch membership_path(subscription), params: { membership: { cost_dollars: "15" } }

        expect(subscription.reload.cost_cents).to eq(1_500)
        expect(response).to redirect_to(person_memberships_path(person))
      end

      it "clears the cost back to standard when left blank" do
        subscription.update!(cost_cents: 1_500)

        patch membership_path(subscription), params: { membership: { cost_dollars: "" } }

        expect(subscription.reload.cost_cents).to be_nil
      end

      it "leaves years already created at the price they were billed" do
        patch membership_path(subscription), params: { membership: { cost_dollars: "60" } }

        expect(existing_year.reload.cost_cents).to eq(Membership::ANNUAL_COST_CENTS)
      end

      it "rejects a negative cost, explaining why" do
        patch membership_path(subscription), params: { membership: { cost_dollars: "-5" } }

        expect(response).to redirect_to(person_memberships_path(person))
        expect(flash[:alert]).to match(/greater than or equal to 0/)
        expect(subscription.reload.cost_cents).to be_nil
      end

      it "explains a resume that conflicts with a newer subscription" do
        subscription.update!(cancelled_at: Time.current)
        create(:membership, person: person)

        patch membership_path(subscription), params: { membership: { cancelled: "0" } }

        expect(response).to redirect_to(person_memberships_path(person))
        expect(flash[:alert]).to match(/already has a membership/)
        expect(subscription.reload).to be_cancelled
      end

      it "ignores a raw cancellation timestamp — only the virtual flag is permitted" do
        patch membership_path(subscription),
          params: { membership: { cost_dollars: "15", cancelled_at: Time.current } }

        expect(subscription.reload.cancelled_at).to be_nil
        expect(subscription.cost_cents).to eq(1_500)
      end
    end
  end

  describe "the status pill" do
    before { sign_in admin }

    it "links to the year's scoped allocations page from the management page" do
      subscription = create(:membership, person: person)
      invoice = membership_invoice_for(subscription: subscription)

      get person_memberships_path(person)

      expect(response.body).to include(allocations_path(allocatable_sgid: invoice.to_sgid.to_s))
    end

    it "is not a link on the profile card, which stays read-only" do
      subscription = create(:membership, person: person)
      invoice = membership_invoice_for(subscription: subscription)

      get person_path(person)

      expect(response.body).to include(invoice.decorate.status_badge.label)
      expect(response.body).not_to include(allocations_path(allocatable_sgid: invoice.to_sgid.to_s))
    end
  end

  describe "the New membership affordance" do
    before { sign_in admin }

    it "is offered when the person has none" do
      get person_memberships_path(person)

      expect(response.body).to include("New membership")
    end

    it "is hidden while an uncancelled subscription exists" do
      create(:membership, person: person)

      get person_memberships_path(person)

      expect(response.body).not_to include("New membership")
    end

    it "is offered again once the only subscription is cancelled" do
      create(:membership, :cancelled, person: person)

      get person_memberships_path(person)

      expect(response.body).to include("New membership")
    end

    it "can be forced back with ?admin=true" do
      create(:membership, person: person)

      get person_memberships_path(person, admin: "true")

      expect(response.body).to include("New membership")
    end
  end

  describe "the Add invoice affordance" do
    let(:subscription) { create(:membership, person: person) }

    before { sign_in admin }

    it "is hidden while the subscription already covers today" do
      membership_invoice_for(subscription: subscription)

      get person_memberships_path(person)

      expect(response.body).not_to include("Add invoice")
    end

    it "is offered once coverage has lapsed" do
      membership_invoice_for(subscription: subscription, start_date: Date.current - 2.years)

      get person_memberships_path(person)

      expect(response.body).to include("Add invoice")
    end

    it "is offered for a subscription with no years at all" do
      subscription

      get person_memberships_path(person)

      expect(response.body).to include("Add invoice")
    end

    it "can be forced back with ?admin=true" do
      membership_invoice_for(subscription: subscription)

      get person_memberships_path(person, admin: "true")

      expect(response.body).to include("Add invoice")
    end
  end

  describe "the policy params filter" do
    let!(:subscription) { create(:membership, person: person) }

    it "lets an admin set the cost" do
      sign_in admin
      patch membership_path(subscription), params: { membership: { cost_dollars: "15" } }

      expect(subscription.reload.cost_cents).to eq(1_500)
    end

    it "permits only the cancelled flag for a non-admin" do
      policy = MembershipPolicy.new(subscription, user: create(:user))
      filtered = policy.apply_scope(
        ActionController::Parameters.new(cost_dollars: "0", cancelled: "1"),
        type: :action_controller_params
      )

      expect(filtered.keys).to contain_exactly("cancelled")
    end

    it "permits both for an admin" do
      policy = MembershipPolicy.new(subscription, user: admin)
      filtered = policy.apply_scope(
        ActionController::Parameters.new(cost_dollars: "0", cancelled: "1"),
        type: :action_controller_params
      )

      expect(filtered.keys).to contain_exactly("cost_dollars", "cancelled")
    end
  end

  describe "PATCH /memberships/:id — cancelling and resuming" do
    let!(:subscription) { create(:membership, person: person) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch membership_path(subscription), params: { membership: { cancelled: "1" } }

      expect(response).to redirect_to(root_path)
      expect(subscription.reload).not_to be_cancelled
    end

    context "as an admin" do
      before { sign_in admin }

      it "stamps the cancellation" do
        patch membership_path(subscription), params: { membership: { cancelled: "1" } }

        expect(subscription.reload).to be_cancelled
        expect(response).to redirect_to(person_memberships_path(person))
      end

      it "leaves an existing year untouched when cancelling" do
        year = create(:membership_invoice, membership: subscription)

        patch membership_path(subscription), params: { membership: { cancelled: "1" } }

        expect(year.reload.end_date).to be_present
        expect(person.reload).to be_membership_current
      end

      it "clears the cancellation on resume, keeping the cost" do
        subscription.update!(cancelled_at: Time.current, cost_cents: 1_500)

        patch membership_path(subscription), params: { membership: { cancelled: "0" } }

        subscription.reload
        expect(subscription).not_to be_cancelled
        expect(subscription.cost_cents).to eq(1_500)
      end

      it "lets the nightly job renew again once resumed" do
        create(:membership_invoice, membership: subscription,
          start_date: Date.current - 1.year + 10.days, end_date: Date.current + 10.days)
        subscription.update!(cancelled_at: Time.current)

        expect { IssueMembershipInvoicesJob.new.perform }.not_to change(MembershipInvoice, :count)

        patch membership_path(subscription), params: { membership: { cancelled: "0" } }

        expect { IssueMembershipInvoicesJob.new.perform }.to change(MembershipInvoice, :count).by(1)
      end
    end
  end
end
