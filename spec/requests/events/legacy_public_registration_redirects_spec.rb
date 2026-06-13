require "rails_helper"

# Only registration links were shared before the public-form routes moved, so we
# keep those old URLs working by redirecting them to the new ones.
RSpec.describe "Legacy public_registration redirects", type: :request do
  let(:event) { create(:event) }

  it "redirects the old submission view to /submission/:slug" do
    get "/events/#{event.id}/public_registration?reg=k7hYgPnuG6dAXOPc1_AAAw"

    expect(response).to redirect_to("/submission/k7hYgPnuG6dAXOPc1_AAAw")
  end

  it "redirects the old registration form page to the registration lane" do
    get "/events/#{event.id}/public_registration/new"

    expect(response).to redirect_to("/events/#{event.id}/forms/registration/new")
  end

  it "preserves query params (e.g. as_visitor) when redirecting the form page" do
    get "/events/#{event.id}/public_registration/new?as_visitor=true"

    expect(response).to redirect_to("/events/#{event.id}/forms/registration/new?as_visitor=true")
  end

  it "redirects the bare old show route (no slug) to the registration form" do
    get "/events/#{event.id}/public_registration"

    expect(response).to redirect_to("/events/#{event.id}/forms/registration/new")
  end
end
