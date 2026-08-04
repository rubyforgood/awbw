require "rails_helper"

RSpec.describe "DuesSubscriptions", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person, first_name: "Grace", last_name: "Hopper") }

  def dues_year(subscription:, cost_cents: 2_500, start_date: Date.current)
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
        past = create(:dues_subscription, :cancelled, person: person, rate_cents: 1_500)
        dues_year(subscription: past, start_date: Date.current - 3.years)
        create(:dues_subscription, person: person)

        get person_dues_subscriptions_path(person)

        expect(response.body).to include("Locked at $15")
        expect(response.body).to include("Standard ($25)")
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

    it "prefills the first year at today and the standard rate" do
      sign_in admin
      get new_person_dues_subscription_path(person)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(Date.current.to_s)
      expect(response.body).to include("25.0")
    end
  end

  describe "POST /people/:person_id/dues_subscriptions" do
    let(:valid_params) do
      {
        dues_subscription: {
          rate_dollars: "",
          dues_registrations_attributes: { "0" => { start_date: Date.current.to_s, cost_dollars: "25" } }
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
        expect(subscription.rate_cents).to be_nil
        expect(year.cost_cents).to eq(2_500)
        expect(year.start_date).to eq(Date.current)
        expect(year.end_date).to eq(Date.current + 1.year - 1.day)
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "locks in a rate when one is given" do
        post person_dues_subscriptions_path(person),
          params: valid_params.deep_merge(dues_subscription: { rate_dollars: "15" })

        expect(person.dues_subscriptions.sole.rate_cents).to eq(1_500)
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
end
