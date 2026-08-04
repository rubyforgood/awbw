require "rails_helper"

RSpec.describe "DuesRegistrations", type: :request do
  let(:admin) { create(:user, :admin) }

  def term_for(name, cost_cents: 2_500, start_date: Date.current)
    person = create(:person, first_name: name, last_name: "Tester")
    create(:dues_registration,
      dues_subscription: create(:dues_subscription, person: person),
      cost_cents: cost_cents,
      start_date: start_date,
      end_date: start_date + 1.year - 1.day)
  end

  describe "GET /dues_registrations" do
    it "is not available to a signed-out visitor" do
      get dues_registrations_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      get dues_registrations_path

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      let(:frame) { { "Turbo-Frame" => "dues_registrations_results" } }

      it "renders the page with the lazy results frame" do
        get dues_registrations_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("dues_registrations_results")
      end

      it "lists each dues year with its person, term and cost in the frame" do
        term_for("Ada")

        get dues_registrations_path, headers: frame

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ada Tester")
        expect(response.body).to include("$25")
      end

      it "shows the status badge for an overdue year" do
        term_for("Behind", start_date: Date.current - Dues::GRACE_PERIOD_DAYS - 1)

        get dues_registrations_path, headers: frame

        expect(response.body).to include("Overdue")
      end

      it "notes a cancelled subscription" do
        term = term_for("Gone")
        term.dues_subscription.update!(cancelled_at: Time.current)

        get dues_registrations_path, headers: frame

        expect(response.body).to include("Subscription cancelled")
      end

      it "says so when there are none" do
        get dues_registrations_path, headers: frame

        expect(response.body).to include("No dues years yet")
      end
    end
  end

  describe "GET /dues_subscriptions/:id/dues_registrations/new" do
    let(:subscription) { create(:dues_subscription, person: create(:person)) }

    it "is not available to a non-admin" do
      sign_in create(:user)
      get new_dues_subscription_dues_registration_path(subscription)

      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "starts today for a subscription with no years" do
        get new_dues_subscription_dues_registration_path(subscription)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(Date.current.to_s)
      end

      it "starts the day after the latest year for a subscription that has one" do
        create(:dues_registration, dues_subscription: subscription,
          start_date: Date.new(2026, 10, 14), end_date: Date.new(2027, 10, 13))

        get new_dues_subscription_dues_registration_path(subscription)

        expect(response.body).to include("2027-10-14")
      end

      it "prefills the cost from a locked rate" do
        subscription.update!(rate_cents: 1_500)

        get new_dues_subscription_dues_registration_path(subscription)

        expect(response.body).to include("15.0")
      end
    end
  end

  describe "POST /dues_subscriptions/:id/dues_registrations" do
    let(:person) { create(:person) }
    let(:subscription) { create(:dues_subscription, person: person) }
    let(:valid_params) do
      { dues_registration: { start_date: Date.current.to_s, cost_dollars: "25" } }
    end

    it "is not available to a non-admin" do
      sign_in create(:user)

      expect { post dues_subscription_dues_registrations_path(subscription), params: valid_params }
        .not_to change(DuesRegistration, :count)
      expect(response).to redirect_to(root_path)
    end

    context "as an admin" do
      before { sign_in admin }

      it "adds the year and derives its end date" do
        expect { post dues_subscription_dues_registrations_path(subscription), params: valid_params }
          .to change(DuesRegistration, :count).by(1)

        year = subscription.dues_registrations.sole
        expect(year.start_date).to eq(Date.current)
        expect(year.end_date).to eq(Date.current + 1.year - 1.day)
        expect(year.cost_cents).to eq(2_500)
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "adds a year to a cancelled subscription" do
        subscription.update!(cancelled_at: Time.current)

        expect { post dues_subscription_dues_registrations_path(subscription), params: valid_params }
          .to change(DuesRegistration, :count).by(1)
      end

      it "rejects a year overlapping an existing one" do
        create(:dues_registration, dues_subscription: subscription,
          start_date: Date.current, end_date: Date.current + 1.year - 1.day)

        expect { post dues_subscription_dues_registrations_path(subscription), params: valid_params }
          .not_to change(DuesRegistration, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("overlapping")
      end
    end
  end

  describe "PATCH /dues_registrations/:id" do
    let(:person) { create(:person) }
    let(:subscription) { create(:dues_subscription, person: person) }
    let!(:year) do
      create(:dues_registration, dues_subscription: subscription,
        start_date: Date.current, end_date: Date.current + 1.year - 1.day, cost_cents: 2_500)
    end

    it "is not available to a non-admin" do
      sign_in create(:user)
      patch dues_registration_path(year), params: { dues_registration: { cost_dollars: "5" } }

      expect(response).to redirect_to(root_path)
      expect(year.reload.cost_cents).to eq(2_500)
    end

    context "as an admin" do
      before { sign_in admin }

      it "corrects the dates and cost" do
        patch dues_registration_path(year), params: {
          dues_registration: {
            start_date: Date.current.to_s,
            end_date: (Date.current + 30.days).to_s,
            cost_dollars: "10"
          }
        }

        year.reload
        expect(year.end_date).to eq(Date.current + 30.days)
        expect(year.cost_cents).to eq(1_000)
        expect(response).to redirect_to(person_dues_subscriptions_path(person))
      end

      it "accepts a cost of zero" do
        patch dues_registration_path(year), params: { dues_registration: { cost_dollars: "0" } }

        expect(year.reload.cost_cents).to eq(0)
      end

      it "refuses a cost below what has already been paid" do
        create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: year, amount: 2_500)

        patch dues_registration_path(year), params: { dues_registration: { cost_dollars: "5" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(year.reload.cost_cents).to eq(2_500)
        expect(response.body).to include("already allocated")
      end

      it "refuses an end date before the start" do
        patch dues_registration_path(year), params: {
          dues_registration: { end_date: (Date.current - 1.day).to_s }
        }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
