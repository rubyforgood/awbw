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
end
