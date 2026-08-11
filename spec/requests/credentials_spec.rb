require "rails_helper"

RSpec.describe "Credentials", type: :request do
  # The public verification page is reachable by slug with no login (mirrors the
  # public ticket pages) — the slug is the authorization. It validates one
  # registrant's single credential, never a roster.
  let(:event) do
    create(:event, title: "Facilitator Training", facilitator_training: true,
                   start_date: 3.days.ago, end_date: 2.days.ago)
  end
  let(:registration) { create(:event_registration, event:, status: "attended") }

  it "renders the credential for an attended facilitator training, with no login" do
    get credential_path(registration.slug)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(registration.registrant.full_name)
    expect(response.body).to include("Facilitator Training")
    expect(response.body).to include("Verified credential")
  end

  it "404s when the training hasn't been attended (no earned credential)" do
    registration.update!(status: "registered")
    get credential_path(registration.slug)

    expect(response).to have_http_status(:not_found)
  end

  it "404s when the event isn't a facilitator training" do
    event.update!(facilitator_training: false)
    get credential_path(registration.slug)

    expect(response).to have_http_status(:not_found)
  end

  it "404s for an unknown slug" do
    get credential_path("no-such-credential")

    expect(response).to have_http_status(:not_found)
  end
end
