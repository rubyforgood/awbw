require "rails_helper"

RSpec.describe "Membership invoices routing", type: :routing do
  it "routes the actions it still has" do
    expect(get: "/membership_invoices").to route_to("membership_invoices#index")
    expect(get: "/membership_invoices/1").to route_to("membership_invoices#show", id: "1")
    expect(get: "/memberships/1/membership_invoices/new").to route_to("membership_invoices#new", membership_id: "1")
    expect(post: "/memberships/1/membership_invoices").to route_to("membership_invoices#create", membership_id: "1")
    expect(delete: "/membership_invoices/1").to route_to("membership_invoices#destroy", id: "1")
  end

  it "has no edit or update route, so an invoice can't be restated" do
    expect(get: "/membership_invoices/1/edit").not_to be_routable
    expect(patch: "/membership_invoices/1").not_to be_routable
    expect(put: "/membership_invoices/1").not_to be_routable
  end
end
