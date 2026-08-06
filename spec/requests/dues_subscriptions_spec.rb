require "rails_helper"

RSpec.describe "DuesSubscriptions", type: :request do
  around { |example| travel_to(Time.current.midday) { example.run } }

  let(:standard_cost) { MoneyFormatter.dollars_from_cents(Dues::ANNUAL_COST_CENTS) }
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Grace", last_name: "Hopper") }

  def dues_year(subscription:, cost_cents: Dues::ANNUAL_COST_CENTS, start_date: Date.current)
    create(:dues_registration,
      dues_subscription: subscription,
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  describe "GET /people/:person_id/dues_subscriptions" do
    it "is not available to a signed-out visitor" do
      get person_dues_subscriptions_path(person)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get person_dues_subscriptions_path(person)

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "names the person and links back to their profile" do
        get person_dues_subscriptions_path(person)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Grace Hopper")
        expect(response.body).to include(person_path(person))
      end

      it "says so when there is no subscription" do
        get person_dues_subscriptions_path(person)

        expect(response.body).to include("No dues subscription yet")
      end

      it "lists every year of a subscription, newest first" do
        subscription = create(:dues_subscription, person: person)
        older = dues_year(subscription: subscription, cost_cents: 0, start_date: Date.current - 1.year)
        newer = dues_year(subscription: subscription)

        get person_dues_subscriptions_path(person)

        body = response.body
        expect(body).to include(newer.decorate.term_range, older.decorate.term_range)
        expect(body.index(newer.decorate.term_range)).to be < body.index(older.decorate.term_range)
      end

      it "lists past subscriptions alongside the current one" do
        past = create(:dues_subscription, :cancelled, person: person, cost_cents: 1_500)
        dues_year(subscription: past, start_date: Date.current - 3.years)
        create(:dues_subscription, person: person)

        get person_dues_subscriptions_path(person)

        expect(response.body).to include("Locked at $15")
        expect(response.body).to include("Standard (#{standard_cost})")
      end

      it "shows the status badge for each year" do
        subscription = create(:dues_subscription, person: person)
        dues_year(subscription: subscription, start_date: Date.current - Dues::GRACE_PERIOD_DAYS - 1)

        get person_dues_subscriptions_path(person)

        expect(response.body).to include("Overdue")
      end

      it "says so when a subscription has no years" do
        create(:dues_subscription, person: person)

        get person_dues_subscriptions_path(person)

        expect(response.body).to include("No dues years yet")
      end
    end
  end

  describe "GET /people/:person_id/dues_subscriptions/new" do
    it "is not available to a non-admin" do
      sign_in create(:user)
      get new_person_dues_subscription_path(person)

      expect(response).to redirect_to(root_path)
    end

    it "prefills the first year at today and the standard cost" do
      sign_in admin
      get new_person_dues_subscription_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Date.current.to_s)
      expect(response.body).to include((Dues::ANNUAL_COST_CENTS / 100.0).to_s)
    end
  end

  describe "POST /people/:person_id/dues_subscriptions" do
    let(:valid_params) do
      {
        dues_subscription: {
          cost_dollars: "",
          dues_registrations_attributes: {
            "0" => { start_date: Date.current.to_s, cost_dollars: (Dues::ANNUAL_COST_CENTS / 100).to_s }
          }
        }
      }
    end

    it "is not available to a non-admin" do
      sign_in create(:user)

      expect { post person_dues_subscriptions_path(person), params: valid_params }
        .not_to change(DuesSubscription, :count)
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "creates the subscription and its first year together" do
        expect { post person_dues_subscriptions_path(person), params: valid_params }
          .to change(DuesSubscription, :count).by(1)
          .and change(DuesRegistration, :count).by(1)

        subscription = person.dues_subscriptions.sole
        year = subscription.dues_registrations.sole
        expect(subscription.cost_cents).to be_nil
        expect(year.cost_cents).to eq(Dues::ANNUAL_COST_CENTS)
        expect(year.start_date).to eq(Date.current)
        expect(year.end_date).to eq(Date.current + 1.year - 1.day)
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "locks in a cost when one is given" do
        post person_dues_subscriptions_path(person),
          params: valid_params.deep_merge(dues_subscription: { cost_dollars: "15" })

        expect(person.dues_subscriptions.sole.cost_cents).to eq(1_500)
      end

      it "accepts a cost of zero for a year already covered" do
        post person_dues_subscriptions_path(person),
          params: valid_params.deep_merge(
            dues_subscription: { dues_registrations_attributes: { "0" => { cost_dollars: "0" } } }
          )

        expect(person.dues_registrations.sole.cost_cents).to eq(0)
      end

      it "rejects a second uncancelled subscription" do
        create(:dues_subscription, person: person)

        expect { post person_dues_subscriptions_path(person), params: valid_params }
          .not_to change(DuesSubscription, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("already has a dues subscription")
      end

      it "rejects a year overlapping an existing one" do
        existing = create(:dues_subscription, :cancelled, person: person)
        create(:dues_registration, dues_subscription: existing,
          start_date: Date.current, end_date: Date.current + 1.year - 1.day)

        expect { post person_dues_subscriptions_path(person), params: valid_params }
          .not_to change(DuesRegistration, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("overlapping")
      end

      it "rejects a missing start date" do
        post person_dues_subscriptions_path(person),
          params: valid_params.deep_merge(
            dues_subscription: { dues_registrations_attributes: { "0" => { start_date: "" } } }
          )

        expect(response).to have_http_status(:unprocessable_content)
        expect(DuesSubscription.count).to eq(0)
      end
    end
  end

  describe "GET /dues_subscriptions/:id/edit" do
    let(:subscription) { create(:dues_subscription, person: person, cost_cents: 1_500) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      get edit_dues_subscription_path(subscription)

      expect(response).to redirect_to(root_path)
    end

    it "shows the current cost and says it applies to future years" do
      sign_in admin
      get edit_dues_subscription_path(subscription)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("15.0")
      expect(response.body).to include("future dues years only")
    end
  end

  describe "PATCH /dues_subscriptions/:id" do
    let!(:subscription) { create(:dues_subscription, person: person) }
    let!(:existing_year) do
      create(:dues_registration, dues_subscription: subscription, cost_cents: Dues::ANNUAL_COST_CENTS)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "15" } }

      expect(response).to redirect_to(root_path)
      expect(subscription.reload.cost_cents).to be_nil
    end

    context "as an admin" do
      before { sign_in admin }

      it "locks in a new cost" do
        patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "15" } }

        expect(subscription.reload.cost_cents).to eq(1_500)
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "clears the cost back to standard when left blank" do
        subscription.update!(cost_cents: 1_500)

        patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "" } }

        expect(subscription.reload.cost_cents).to be_nil
      end

      it "leaves years already created at the price they were billed" do
        patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "60" } }

        expect(existing_year.reload.cost_cents).to eq(Dues::ANNUAL_COST_CENTS)
      end

      it "rejects a negative cost, explaining why" do
        patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "-5" } }

        expect(response).to redirect_to(person_dues_subscriptions_path(person))
        expect(flash[:alert]).to match(/greater than or equal to 0/)
        expect(subscription.reload.cost_cents).to be_nil
      end

      it "explains a resume that conflicts with a newer subscription" do
        subscription.update!(cancelled_at: Time.current)
        create(:dues_subscription, person: person)

        patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "0" } }

        expect(response).to redirect_to(person_dues_subscriptions_path(person))
        expect(flash[:alert]).to match(/already has a dues subscription/)
        expect(subscription.reload).to be_cancelled
      end

      it "ignores a raw cancellation timestamp — only the virtual flag is permitted" do
        patch dues_subscription_path(subscription),
          params: { dues_subscription: { cost_dollars: "15", cancelled_at: Time.current } }

        expect(subscription.reload.cancelled_at).to be_nil
        expect(subscription.cost_cents).to eq(1_500)
      end
    end
  end

  describe "the New subscription affordance" do
    before { sign_in admin }

    it "is offered when the person has none" do
      get person_dues_subscriptions_path(person)

      expect(response.body).to include("New subscription")
    end

    it "is hidden while an uncancelled subscription exists" do
      create(:dues_subscription, person: person)

      get person_dues_subscriptions_path(person)

      expect(response.body).not_to include("New subscription")
    end

    it "is offered again once the only subscription is cancelled" do
      create(:dues_subscription, :cancelled, person: person)

      get person_dues_subscriptions_path(person)

      expect(response.body).to include("New subscription")
    end

    it "can be forced back with ?admin=true" do
      create(:dues_subscription, person: person)

      get person_dues_subscriptions_path(person, admin: "true")

      expect(response.body).to include("New subscription")
    end
  end

  describe "the Add year affordance" do
    let(:subscription) { create(:dues_subscription, person: person) }

    before { sign_in admin }

    it "is hidden while the subscription already covers today" do
      dues_year(subscription: subscription)

      get person_dues_subscriptions_path(person)

      expect(response.body).not_to include("Add year")
    end

    it "is offered once coverage has lapsed" do
      dues_year(subscription: subscription, start_date: Date.current - 2.years)

      get person_dues_subscriptions_path(person)

      expect(response.body).to include("Add year")
    end

    it "is offered for a subscription with no years at all" do
      subscription

      get person_dues_subscriptions_path(person)

      expect(response.body).to include("Add year")
    end

    it "can be forced back with ?admin=true" do
      dues_year(subscription: subscription)

      get person_dues_subscriptions_path(person, admin: "true")

      expect(response.body).to include("Add year")
    end
  end

  describe "the policy params filter" do
    let!(:subscription) { create(:dues_subscription, person: person) }

    it "lets an admin set the cost" do
      sign_in admin
      patch dues_subscription_path(subscription), params: { dues_subscription: { cost_dollars: "15" } }

      expect(subscription.reload.cost_cents).to eq(1_500)
    end

    it "permits only the cancelled flag for a non-admin" do
      policy = DuesSubscriptionPolicy.new(subscription, user: create(:user))
      filtered = policy.apply_scope(
        ActionController::Parameters.new(cost_dollars: "0", cancelled: "1"),
        type: :action_controller_params
      )

      expect(filtered.keys).to contain_exactly("cancelled")
    end

    it "permits both for an admin" do
      policy = DuesSubscriptionPolicy.new(subscription, user: admin)
      filtered = policy.apply_scope(
        ActionController::Parameters.new(cost_dollars: "0", cancelled: "1"),
        type: :action_controller_params
      )

      expect(filtered.keys).to contain_exactly("cost_dollars", "cancelled")
    end
  end

  describe "PATCH /dues_subscriptions/:id — cancelling and resuming" do
    let!(:subscription) { create(:dues_subscription, person: person) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "1" } }

      expect(response).to redirect_to(root_path)
      expect(subscription.reload).not_to be_cancelled
    end

    context "as an admin" do
      before { sign_in admin }

      it "stamps the cancellation" do
        patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "1" } }

        expect(subscription.reload).to be_cancelled
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "leaves an existing year untouched when cancelling" do
        year = create(:dues_registration, dues_subscription: subscription)

        patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "1" } }

        expect(year.reload.end_date).to be_present
        expect(person.reload).to be_dues_current
      end

      it "clears the cancellation on resume, keeping the cost" do
        subscription.update!(cancelled_at: Time.current, cost_cents: 1_500)

        patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "0" } }

        subscription.reload
        expect(subscription).not_to be_cancelled
        expect(subscription.cost_cents).to eq(1_500)
      end

      it "lets the nightly job renew again once resumed" do
        create(:dues_registration, dues_subscription: subscription,
          start_date: Date.current - 1.year + 10.days, end_date: Date.current + 10.days)
        subscription.update!(cancelled_at: Time.current)

        expect { RenewDuesTermsJob.new.perform }.not_to change(DuesRegistration, :count)

        patch dues_subscription_path(subscription), params: { dues_subscription: { cancelled: "0" } }

        expect { RenewDuesTermsJob.new.perform }.to change(DuesRegistration, :count).by(1)
      end
    end
  end
end
