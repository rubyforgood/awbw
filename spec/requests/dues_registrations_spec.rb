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
end
