require "rails_helper"

RSpec.describe "Discounts", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "POST /discounts/allocation_form" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }

    it "renders the discount form with the allocated-to registration link" do
      post allocation_form_discounts_path,
        params: { allocatable_sgid: registration.to_sgid.to_s },
        as: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("New discount")
      expect(response.body).to include("Allocated to:")
      expect(response.body).to include(edit_event_registration_path(registration))
    end
  end
end
